module AFMotion
  class HTTPResult
    attr_accessor :object, :error, :task

    def initialize(task, responseObject, error)
      self.task = task
      self.object = responseObject
      self.error = error
    end

    # alias_method doesn't seem to work here
    def operation
      task
    end

    def success?
      !failure?
    end

    def failure?
      !!error
    end

    def status_code
      if self.task && self.task.response
        self.task.response.statusCode
      else
        nil
      end
    end
  end
end
