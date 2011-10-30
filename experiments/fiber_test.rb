require 'fiber'

class FiberPool
  # Prepare a list of fibers that are able to run different blocks of code
  # every time. Once a fiber is done with its block, it attempts to fetch
  # another one from the queue
  def initialize(count = 100)
    @fibers,@busy_fibers,@queue = [],{},[]
    
    count.times do |i|
      add_fiber()
    end
  end
  
  def add_fiber
    fiber = Fiber.new do |block|
      loop do
        block.call
        unless @queue.empty?
          block = @queue.shift
        else
          @busy_fibers.delete(Fiber.current.object_id)
          @fibers.unshift Fiber.current
          block = Fiber.yield
        end
      end
    end
    
    @fibers << fiber
    fiber
  end

  # If there is an available fiber use it, otherwise, leave it to linger
  # in a queue
  def spawn(&block)
    # resurrect dead fibers
    @busy_fibers.values.reject(&:alive?).each do |f|
      @busy_fibers.delete(f.object_id)
      add_fiber()
    end
    
    if fiber = @fibers.shift
      @busy_fibers[fiber.object_id] = fiber
      fiber.resume(block)
    else
      @queue << block
    end
    
    fiber
  end  
end


class WebMessageHandler
  def initialize
    @fiber_delegate = Fiber.new do
      process
    end
  end
  
  def resume
    @fiber_delegate.resume
  end
  
  def process
    while value = input
      handle_value(value)
    end
  end
  
  def handle_value(value)
    output(value)
  end
  
  def input
    source.resume
  end
  
  def output(value)
    Fiber.yield(value)
  end
end
