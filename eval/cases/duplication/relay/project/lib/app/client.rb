module App
  class Client
    def post(path, body) = request(:post, path, body, headers: @headers.merge(json: true))
    def patch(path, body) = request(:patch, path, body, headers: @headers.merge(json: true))
    def put(path, body) = request(:put, path, body, headers: @headers.merge(json: true))

    private

    def request(verb, path, body, headers:) = @http.call(verb, path, body, headers)
  end
end
