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
class ApplicationController < ActionController::Base
  protect_from_forgery
  COOKIE_NAME_FOR_TOKEN = "identity/getCookieNameForToken"
  IS_TOKEN_VALID = "identity/isTokenValid"
  LOGIN_URL = "UI/Login?goto="
  USER_ATTRIBUTES = "identity/attributes"

  def check_authentication
    @opensso_location = URI.parse(APP_CONFIG['opensso_location'])
    @http = Net::HTTP.new(@opensso_location.host, @opensso_location.port)

    # Get name of the token cookie
    token_cookie_name = get_cookie_name_for_token
    # Retrieve that cookie
    token_cookie = get_token_cookie(token_cookie_name)

    # If this cookie is not valid, redirect to login page.
    redirect_to_opensso && return unless validate_token(token_cookie)
    # If valid, retrieve user details.
    @opensso_user = get_opensso_user(token_cookie)
  end

  def get_cookie_name_for_token
    req = Net::HTTP::Post.new("#{@opensso_location}/#{COOKIE_NAME_FOR_TOKEN}")
    res = @http.request(req)
    res.body.split('=').last.strip
  end

  def get_token_cookie(token_cookie_name)
    token_cookie = CGI.unescape(request.cookies.fetch(token_cookie_name, nil).to_s.gsub('+', '%2B'))
    token_cookie != '' ? token_cookie : nil
  end

  def validate_token(token_cookie)
    return if token_cookie == nil
    # odd, post does not seem to work?
    req = Net::HTTP::Get.new("#{@opensso_location}/#{IS_TOKEN_VALID}?tokenid=#{token_cookie}")
    res = @http.request(req)
    res.body.split('=').last.strip == 'true'
  end

  def redirect_to_opensso
    redirect_to "#{@opensso_location}/#{LOGIN_URL}" + url_for({:only_path => false})
  end
  
  def get_opensso_user(token_cookie)
    return if token_cookie == nil
    
    opensso_user = Hash.new
    attribute_name = ''
    
    req = Net::HTTP::Post.new("#{@opensso_location}/#{USER_ATTRIBUTES}")

    req.set_form_data({"subjectid" => token_cookie})
    req['Cookie'] = token_cookie
    res = @http.request(req)

    Rails.logger.info(res)
    
    lines = res.body.split(/\n/)
    
    lines.each do |line|
      if line.match(/^userdetails.attribute.name=/)
        attribute_name = line.gsub(/^userdetails.attribute.name=/, '')
        opensso_user[attribute_name] = Array.new
      elsif line.match(/^userdetails.attribute.value=/)
        opensso_user[attribute_name] << line.gsub(/^userdetails.attribute.value=/, '')
      end
    end
    
    opensso_user
  end
end

