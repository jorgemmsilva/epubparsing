require 'paperclip'
require 'jquery-rails'

module Epubparser
  class Engine < ::Rails::Engine
  	engine_name "epubparser"
    isolate_namespace Epubparser
  end
end
