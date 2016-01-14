require_dependency "epubparser/application_controller"

module Epubparser
  class EpubsController < ApplicationController
    before_action :set_epub, only: [:show, :edit, :update, :destroy]


    # GET /epubs/1
    def show

    	ActiveSupport.escape_html_entities_in_json = true 

      epub = Epub.find(params[:id])

      respond_to do |format|
      	format.html # show.html.erb
      	format.json { render json: epub.get_data}
      end

    end

    # GET /epubs/new
    def new
      @epub = Epub.new
    end


    # POST /epubs
    def create

      @upload = Epub.new({epub: params[:epub].first})

      respond_to do |format|

        if @upload.save

          UploadEpubGetMetadataJob.perform_later(@upload.id)

          format.json { head :no_content}

        else
          format.html { render action: "new" }
          format.json { render json: @upload.errors, status: :unprocessable_entity }
        end
      end

    end

    # PATCH/PUT /epubs/1
    def update
      @upload = Epub.new({epub: params[:epub].first})

      respond_to do |format|

        if @upload.save

          UploadEpubGetMetadataJob.perform_later(@upload.id)

          format.json { head :no_content}

        else
          format.html { render action: "new" }
          format.json { render json: @upload.errors, status: :unprocessable_entity }
        end
      end
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_epub
        @epub = Epub.find(params[:id])
      end

      # Only allow a trusted parameter "white list" through.
      def epub_params
        params.require(:epub).permit(:book)
      end

    end
end
