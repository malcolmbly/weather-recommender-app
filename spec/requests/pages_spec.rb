require 'rails_helper'

RSpec.describe "Pages", type: :request do
  describe "GET /home" do
    it "returns http success" do
      get "/pages/home"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /echo" do
    let (:valid_params) do
      {
        input: "test input"
      }
    end
    it "returns http success" do
      post "/pages/echo", params: valid_params
      expect(response).to have_http_status(:success)
    end
  end
end
