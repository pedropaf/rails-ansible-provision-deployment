Rails.logger = Sidekiq.logger
ActiveRecord::Base.logger = Sidekiq.logger