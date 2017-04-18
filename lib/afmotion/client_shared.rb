module AFMotion
  # ported from https://github.com/AFNetworking/AFNetworking/blob/master/UIKit%2BAFNetworking/UIProgressView%2BAFNetworking.m
  class SessionObserver

    def initialize(task, callback)
      @callback = callback
      task.addObserver(self, forKeyPath:"state", options:0, context:nil)
      task.addObserver(self, forKeyPath:"countOfBytesSent", options:0, context:nil)
    end

    def observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
      if keyPath == "countOfBytesSent"
        # Could be -1, see https://github.com/AFNetworking/AFNetworking/issues/1354
        expectation = (object.countOfBytesExpectedToSend > 0) ? object.countOfBytesExpectedToSend.to_f : nil
        @callback.call(nil, object.countOfBytesSent.to_f, expectation)
      end

      if keyPath == "state" && object.state == NSURLSessionTaskStateCompleted
        begin
          object.removeObserver(self, forKeyPath: "state")
          object.removeObserver(self, forKeyPath: "countOfBytesSent")
          @callback = nil
        rescue
        end
      end
    end
  end

  module ClientShared
    def headers
      requestSerializer.headers
    end

    def all_headers
      requestSerializer.HTTPRequestHeaders
    end

    def authorization=(authorization)
      requestSerializer.authorization = authorization
    end

    def multipart_post(path, parameters = {}, &callback)
      create_multipart_operation(:post, path, parameters, &callback)
    end

    def multipart_put(path, parameters = {}, &callback)
      create_multipart_operation(:put, path, parameters, &callback)
    end

    def create_multipart_operation(http_method, path, parameters = {}, &callback)
      inner_callback = Proc.new do |result, form_data, progress|
        case callback.arity
        when 1
          callback.call(result)
        when 2
          callback.call(result, form_data)
        when 3
          callback.call(result, form_data, progress)
        end
      end

      multipart_callback = nil
      if callback.arity > 1
        multipart_callback = lambda { |formData|
          inner_callback.call(nil, formData)
        }
      end
      upload_callback = nil
      if callback.arity > 2
        upload_callback = lambda do |progress|
          inner_callback.call(nil, nil, progress)
        end
      end

      http_method = http_method.to_s.upcase
      url = NSURL.URLWithString(path, relativeToURL:self.baseURL).absoluteString
      serialization_error_ptr = Pointer.new(:object)
      request = requestSerializer.multipartFormRequestWithMethod(http_method,
        URLString: url,
        parameters: parameters,
        constructingBodyWithBlock: multipart_callback,
        error: serialization_error_ptr)

      if serialization_error_ptr && serialization_error_ptr[0]
        queue = self.completionQueue || Dispatch::Queue.main
        queue.async { AFMotion::Operation.failure_block(inner_callback).call(nil, serialization_error_ptr[0]) }
        return nil
      end

      task = self.uploadTaskWithStreamedRequest(request,
        progress: upload_callback,
        completionHandler: lambda do |_response, response_object, error|
          error ? AFMotion::Operation.failure_block(inner_callback).call(task, error) : AFMotion::Operation.success_block_for_http_method(:post, inner_callback).call(task, response_object)
        end)
      task.resume
      task
    end

    def create_operation(http_method, path, parameters = {}, &callback)
      success_block = AFMotion::Operation.success_block_for_http_method(http_method, callback)
      failure_block = AFMotion::Operation.failure_block(callback)
      progress_block = parameters.delete(:progress_block) if parameters && parameters[:progress_block]

      http_method = http_method.to_s.upcase
      url = NSURL.URLWithString(path, relativeToURL:self.baseURL).absoluteString
      serialization_error_ptr = Pointer.new(:object)
      request = requestSerializer.requestWithMethod(http_method,
        URLString: url,
        parameters: parameters,
        error: serialization_error_ptr)

      if serialization_error_ptr && serialization_error_ptr[0]
        queue = self.completionQueue || Dispatch::Queue.main
        queue.async { failure_block.call(nil, serialization_error_ptr[0]) }
        return nil
      end

      task = self.dataTaskWithRequest(request,
        uploadProgress: nil,
        downloadProgress: progress_block,
        completionHandler: lambda do |_response, response_object, error|
          error ? failure_block.call(task, error) : success_block.call(task, response_object)
        end)
      task.resume
      task
    end

    alias_method :create_task, :create_operation

    private
    # To force RubyMotion pre-compilation of these methods
    def dummy
      self.GET("", parameters: nil, success: nil, failure: nil)
      self.HEAD("", parameters: nil, success: nil, failure: nil)
      self.POST("", parameters: nil, success: nil, failure: nil)
      self.POST("", parameters: nil, constructingBodyWithBlock: nil, success: nil, failure: nil)
      self.PUT("", parameters: nil, success: nil, failure: nil)
      self.DELETE("", parameters: nil, success: nil, failure: nil)
      self.PATCH("", parameters: nil, success: nil, failure: nil)
    end
  end
end
