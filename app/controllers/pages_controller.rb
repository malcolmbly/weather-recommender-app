class PagesController < ApplicationController
  def home
    # Check if a form submission occurred (if params includes 'user_input')
    if params[:user_input].present?
      # Store the submitted input in an instance variable
      @user_input = params[:user_input]
    else
      # Initialize the variable if no input was submitted yet
      @user_input = nil
    end
  end
end
