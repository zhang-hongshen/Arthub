#if os(macOS)
import Foundation
import MCP
import Network

/// Serves `AgentTools` to AI agents on this Mac (such as ModelCraft) as a stateless Streamable
/// HTTP MCP server.
///
/// - It listens only on 127.0.0.1, on a port the system picks, and answers only `POST /mcp`.
/// - Every request must carry `Authorization: Bearer <token>`; the token is new on every launch.
/// - Once listening, it writes `{"url": …, "token": …}` to `mcp.json` in
///   `Application Support/<bundle ID>/`, where clients find it.
///
/// Each HTTP request gets its own MCP `Server`: the SDK's server accepts one `initialize` in
/// its life, and clients open a new connection per call. Responses are single JSON bodies,
/// never event streams, and every connection closes after its response.
final class AgentServer: @unchecked Sendable {
    static let path = "/mcp"
    /// The largest request accepted, headers and body together.
    static let maxRequestSize = 1 << 20

    let tools: AgentTools
    let token: String
    private let queue = DispatchQueue(label: "Arthub.AgentServer")
    private var listener: NWListener?

    init(tools: AgentTools, token: String = AgentServer.makeToken()) {
        self.tools = tools
        self.token = token
    }

    /// 32 random bytes as hex.
    static func makeToken() -> String {
        var generator = SystemRandomNumberGenerator()
        return (0..<32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator)) }.joined()
    }

    /// Starts listening; the endpoint file is written when the listener is ready.
    func start() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        parameters.acceptLocalOnly = true
        let listener = try NWListener(using: parameters)
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            switch state {
            case .ready:
                if let port = listener?.port?.rawValue { self?.writeEndpoint(port: Int(port)) }
            case .failed(let error):
                print("The agent server stopped: \(error)")
                listener?.cancel()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    // MARK: - Endpoint file

    static func endpointFile() throws -> URL {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.zhanghongshen.Arthub"
        return try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(bundleId, isDirectory: true)
            .appendingPathComponent("mcp.json")
    }

    static func endpointJSON(port: Int, token: String) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: ["url": "http://127.0.0.1:\(port)\(path)", "token": token],
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }

    private func writeEndpoint(port: Int) {
        do {
            let url = try Self.endpointFile()
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.endpointJSON(port: port, token: token).write(to: url, options: .atomic)
            // The token is a password for this launch: only the user may read it.
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            print("The agent server's endpoint file was not written: \(error)")
        }
    }

    // MARK: - Connections

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    /// Reads until a whole request has arrived, answers it, and closes the connection.
    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return connection.cancel() }
            var buffer = buffer
            if let data { buffer.append(data) }
            switch AgentHTTP.parse(buffer, maxSize: Self.maxRequestSize) {
            case .incomplete:
                if error == nil && !isComplete {
                    self.receive(on: connection, buffer: buffer)
                } else {
                    connection.cancel()
                }
            case .invalid(let status):
                self.send(.error(statusCode: status, .invalidRequest(AgentHTTP.reason(for: status))), on: connection)
            case .request(let request):
                Task {
                    let response = await self.handle(request)
                    self.send(response, on: connection)
                }
            }
        }
    }

    private func send(_ response: HTTPResponse, on connection: NWConnection) {
        connection.send(content: AgentHTTP.serialize(response), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Requests

    /// Answers one HTTP request: checks the path and the token, then runs it through a new MCP server.
    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        guard request.path == Self.path else {
            return .error(statusCode: 404, .invalidRequest("Not Found: the MCP endpoint is \(Self.path)"))
        }
        guard request.header(HTTPHeaderName.authorization) == "Bearer " + token else {
            return .error(statusCode: 401, .invalidRequest("Unauthorized"), extraHeaders: [HTTPHeaderName.wwwAuthenticate: "Bearer"])
        }
        let server = Server(
            name: AgentTools.serverName,
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            instructions: AgentTools.instructions,
            capabilities: .init(tools: .init(listChanged: false))
        )
        let tools = self.tools
        _ = await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: AgentTools.all)
        }
        _ = await server.withMethodHandler(CallTool.self) { params in
            await tools.call(params)
        }
        // The default checks: Host and Origin are this Mac, the client accepts JSON, the body is JSON.
        let transport = StatelessHTTPServerTransport()
        do {
            try await server.start(transport: transport)
        } catch {
            return .error(statusCode: 500, .internalError("The MCP server did not start: \(error.localizedDescription)"))
        }
        let response = await transport.handleRequest(request)
        await server.stop()
        return response
    }
}

/// The small part of HTTP/1.1 the agent server needs: one request per connection, with a
/// `Content-Length` body, and responses that close the connection.
enum AgentHTTP {
    enum Parsed {
        /// More bytes are needed.
        case incomplete
        /// The request cannot be served; answer with this status.
        case invalid(Int)
        case request(HTTPRequest)
    }

    static func parse(_ data: Data, maxSize: Int) -> Parsed {
        let bytes = [UInt8](data)
        guard let headerEnd = bytes.firstRange(of: Array("\r\n\r\n".utf8)) else {
            return bytes.count > maxSize ? .invalid(431) : .incomplete
        }
        guard let head = String(bytes: bytes[..<headerEnd.lowerBound], encoding: .utf8) else { return .invalid(400) }
        var lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count == 3, requestLine[2].hasPrefix("HTTP/1.") else { return .invalid(400) }

        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { return .invalid(400) }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            // Repeated headers are joined, as HTTP allows.
            headers[name] = headers[name].map { $0 + ", " + value } ?? value
        }
        let request = HTTPRequest(method: String(requestLine[0]), headers: headers)
        if request.header("Transfer-Encoding") != nil { return .invalid(411) }
        var length = 0
        if let value = request.header("Content-Length") {
            guard let parsed = Int(value), parsed >= 0 else { return .invalid(400) }
            length = parsed
        }
        guard headerEnd.upperBound + length <= maxSize else { return .invalid(413) }
        guard bytes.count >= headerEnd.upperBound + length else { return .incomplete }

        let target = String(requestLine[1])
        return .request(HTTPRequest(
            method: request.method,
            headers: headers,
            body: length > 0 ? Data(bytes[headerEnd.upperBound..<(headerEnd.upperBound + length)]) : nil,
            path: target.split(separator: "?", maxSplits: 1).first.map(String.init) ?? target
        ))
    }

    static func serialize(_ response: HTTPResponse) -> Data {
        let body = response.bodyData ?? Data()
        var headers = response.headers
        headers["Content-Length"] = String(body.count)
        headers["Connection"] = "close"
        var head = "HTTP/1.1 \(response.statusCode) \(reason(for: response.statusCode))\r\n"
        for (name, value) in headers.sorted(by: { $0.key < $1.key }) {
            head += "\(name): \(value)\r\n"
        }
        head += "\r\n"
        return Data(head.utf8) + body
    }

    static func reason(for status: Int) -> String {
        switch status {
        case 200: "OK"
        case 202: "Accepted"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 406: "Not Acceptable"
        case 411: "Length Required"
        case 413: "Content Too Large"
        case 415: "Unsupported Media Type"
        case 421: "Misdirected Request"
        case 431: "Request Header Fields Too Large"
        default: "Error"
        }
    }
}
#endif
