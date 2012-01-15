class HomeController < ApplicationController
  before_filter :check_authentication, :only => [:index]

  def index
    # Do a service call here.
  end

end
