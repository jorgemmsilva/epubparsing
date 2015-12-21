require 'test_helper'

module Epubparser
  class EpubsControllerTest < ActionController::TestCase
    setup do
      @epub = epubparser_epubs(:one)
      @routes = Engine.routes
    end

    test "should get index" do
      get :index
      assert_response :success
      assert_not_nil assigns(:epubs)
    end

    test "should get new" do
      get :new
      assert_response :success
    end

    test "should create epub" do
      assert_difference('Epub.count') do
        post :create, epub: { book: @epub.book }
      end

      assert_redirected_to epub_path(assigns(:epub))
    end

    test "should show epub" do
      get :show, id: @epub
      assert_response :success
    end

    test "should get edit" do
      get :edit, id: @epub
      assert_response :success
    end

    test "should update epub" do
      patch :update, id: @epub, epub: { book: @epub.book }
      assert_redirected_to epub_path(assigns(:epub))
    end

    test "should destroy epub" do
      assert_difference('Epub.count', -1) do
        delete :destroy, id: @epub
      end

      assert_redirected_to epubs_path
    end
  end
end
