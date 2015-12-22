Epubparser::Engine.routes.draw do
  resources :epubs do
    get "metadata"
    get "assets"
  end
end
