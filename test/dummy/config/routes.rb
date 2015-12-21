Rails.application.routes.draw do

  mount Epubparser::Engine => "/epubparser"
end
