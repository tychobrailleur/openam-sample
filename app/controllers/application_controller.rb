# -*- coding: utf-8 -*-
# The application controller provides the methods to authenticate against opensso.
# To use in a controller, use before_filter :check_authentication
#
# The authentication follows the following steps:
# 1. Retrieve the name of the cookie holding the sso token.
# 2. Once this name is found, retrieve the cookie with that name.
# 3. Validate the cookie against the sso server.
# 4. If the cookie is not valid, redirect to the login page, and that’s it.
# 5. If it is, retrieve the associated user details.
#
# See also http://developers.sun.com/identity/reference/techart/app-integration.html
# for more details.
#

class OpenAM
  include HTTParty
  base_uri APP_CONFIG['opensso_location']
  COOKIE_NAME_FOR_TOKEN = "/identity/getCookieNameForToken"
  IS_TOKEN_VALID = "/identity/isTokenValid"
  USER_ATTRIBUTES = "/identity/attributes"

  def get_cookie_name_for_token
    response = self.class.post(COOKIE_NAME_FOR_TOKEN, {})
    response.body.split('=').last.strip
  end

  def get_token_cookie(request, token_cookie_name)
    token_cookie = CGI.unescape(request.cookies.fetch(token_cookie_name, nil).to_s.gsub('+', '%2B'))
    token_cookie != '' ? token_cookie : nil    
  end

  def validate_token(token)
    response = self.class.get("#{IS_TOKEN_VALID}?tokenid=#{token}", {})
    response.body.split('=').last.strip == 'true'
  end

  def get_opensso_user(token_cookie_name, token)
    self.class.cookies({ token_cookie_name => token })
    self.class.post("#{USER_ATTRIBUTES}", {:subjectid => token})
  end
end


class ApplicationController < ActionController::Base
  protect_from_forgery

  LOGIN_URL = "UI/Login?goto="
  LOGOUT_URL = "UI/Login?goto="

  def check_authentication
    @openam = OpenAM.new

    # Get name of the token cookie
    token_cookie_name = @openam.get_cookie_name_for_token
    # Retrieve that cookie
    token_cookie = @openam.get_token_cookie(request, token_cookie_name)

    if valid_token?(token_cookie)
      # If valid, retrieve user details.
      response = @openam.get_opensso_user(token_cookie_name, token_cookie)
      @opensso_user = parse_user_attribute_response(response)
    else
      # If not valid, redirect to login page.
      redirect_to_login
    end
  end

  private
  def valid_token?(token)
    token != nil and @openam.validate_token(token)
  end

  def redirect_to_login
    redirect_to "#{APP_CONFIG['opensso_location']}/#{LOGIN_URL}" + url_for({:only_path => false})
  end
  
  def parse_user_attribute_response(response)
    opensso_user = Hash.new{ |h,k| h[k] = Array.new }
    attribute_name = ''
    
    Rails.logger.debug(response)

    lines = response.body.split(/\n/)
    lines.each do |line|
      if line.match(/^userdetails.attribute.name=/)
        attribute_name = line.gsub(/^userdetails.attribute.name=/, '').strip
      elsif line.match(/^userdetails.attribute.value=/)
        opensso_user[attribute_name] << line.gsub(/^userdetails.attribute.value=/, '').strip
      end
    end
    
    opensso_user
  end
end

