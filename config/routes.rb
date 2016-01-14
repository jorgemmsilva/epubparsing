Epubparser::Engine.routes.draw do
  resources :epubs, only: [:create] do
    member do
      patch :update, as: "update"
    end
  end
end
