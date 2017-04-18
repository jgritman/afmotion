module AFMotion
  module Operation
    module_function

    def success_block_for_http_method(http_method, callback)
      if http_method.downcase.to_sym == :head
        return lambda { |task|
          result = AFMotion::HTTPResult.new(task, nil, nil)
          callback.call(result)
        }
      end

      lambda { |task, responseObject|
        result = AFMotion::HTTPResult.new(task, responseObject, nil)
        callback.call(result)
      }
    end

    def failure_block(callback)
      lambda { |task, error|
        response_object = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey]
        result = AFMotion::HTTPResult.new(task, response_object, error)
        callback.call(result)
      }
    end
  end

  module Serialization
    def with_request_serializer(serializer_klass)
      self.requestSerializer = serializer_klass.serializer
      self
    end

    def with_response_serializer(serializer_klass)
      self.responseSerializer = serializer_klass.serializer
      self
    end

    def http!
      with_request_serializer(AFHTTPRequestSerializer).
        with_response_serializer(AFHTTPResponseSerializer)
    end

    def json!
      with_request_serializer(AFJSONRequestSerializer).
        with_response_serializer(AFJSONResponseSerializer)
    end

    def xml!
        with_response_serializer(AFXMLParserResponseSerializer)
    end

    def plist!
      with_request_serializer(AFPropertyListRequestSerializer).
        with_response_serializer(AFPropertyListResponseSerializer)
    end

    def image!
      with_response_serializer(AFImageResponseSerializer)
    end
  end
end

class AFHTTPRequestOperation
  include AFMotion::Serialization
end

class AFHTTPSessionManager
  include AFMotion::Serialization
end