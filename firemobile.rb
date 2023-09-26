require 'faraday'
require 'pry'
require 'hash_with_indifferent_access_duplicate_warning'
require 'cgi'

class Firemobile

    attr_accessor :conn
    attr_reader :response

    BASE_URL = ENV['FIREMOBILE_URL'].freeze
    USERNAME = ENV['FIREMOBILE_USERNAME'].freeze
    PASSWORD = ENV['FIREMOBILE_PASSWORD'].freeze

    def initialize()
      @conn = Faraday.new(url: BASE_URL)
    end

    def response_hash
        response.to_hash
    end

    def response_body_hash
        JSON.parse(response.body)
    end
    
    %w(sms hlr).each do |kind|
        define_method "send_#{kind}".to_sym do |**params|
            response = conn.post(send("#{__method__.to_s}_cmd")) do |req|
                req.body = send("#{__method__.to_s}_params", **params)
            end
            raise validate(response)[0] if validate(response)[1]
            @response = response
        end

        define_method "send_#{kind}_params" do |**params|
            params = ActiveSupport::HashWithIndifferentAccess.new(params.merge(credential_hash))
            c_keys = capture_keys(params.keys, send("#{__method__.to_s.gsub('_params','')}_opts"))
            raise 'missing mandatory field' if params['gw-from'.to_sym].nil? || params['gw-to'.to_sym].nil? || params['gw-text'.to_sym].nil?
            raise 'invalid key field' unless params.keys.any? { |x| c_keys.include?(x) }

            params
        end

        private "send_#{kind}_params".to_sym
    end

    private

    def validate(res)
      [
        res.body.split('=')[-1].gsub('+',' '),
        res.body.split('&').any? { |x| x.match?(/err_msg/) }
      ]
    end

    def capture_keys(entered_keys, opt_keys)
        (entered_keys + opt_keys)
    end
    
    def credential_hash
        @credential_hash = { "gw-username": USERNAME, "gw-password" => PASSWORD }
    end

    def send_sms_cmd
        '/cgi-bin/sendsms'
    end

    def send_hlr_cmd
        '/cgi-bin/sendhlr'
    end

    def send_sms_opts
        %w(gw-udh gw-coding gw-dlr-mask gw-dlr-url gw-mclass gw-alt-dcs gw-charset gw-validity)
    end

    def send_hlr_opts
        %w(gw-charset)
    end
end

# Examples
#o = Firemobile.new
#res = o.send_sms('gw-from' => '68886', 'gw-to' => '60197570530', 'gw-text' => 'test using library')
#puts res.inspect
