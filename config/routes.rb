Rails.application.routes.draw do
  root 'index#index'
  
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'
end
