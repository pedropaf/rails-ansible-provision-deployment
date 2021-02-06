class HardWorker
  include Sidekiq::Worker

  def perform(*args)
    # Do something
    Rails.logger.info "Things are happening in worker."
  end
end
