require 'httparty'
class Deposit

  include HTTParty
  base_uri "https://api.mch.weixin.qq.com"
  format  :xml

  # APPID = "wxfe4fd89f6f5f9f57"
  # SECRET = "01265a8ba50284999508d680f7387664"
  # APIKEY = "1juOmajJrHO3f2NFA0a8dIYy2qAamtnK"
  # MCH_ID = "1388434302"
  # NOTIFY_URL = "http://#{Rails.configuration.domain}/user_mobile/courses/notify"

  # APPID = "wxfe4fd89f6f5f9f57"
  APPID = Rails.configuration.wechat_pay_app_id
  # SECRET = "01265a8ba50284999508d680f7387664"
  SECRET = Rails.configuration.wechat_pay_app_key
  # APIKEY = "1juOmajJrHO3f2NFA0a8dIYy2qAamtnK"
  APIKEY = Rails.configuration.wechat_pay_api_key
  MCH_ID = Rails.configuration.wechat_mch_id
  NOTIFY_URL = "http://#{Rails.configuration.domain}/user_mobile/settings/notify"

  include Mongoid::Document
  include Mongoid::Timestamps

  field :amount, type: Integer, default: 100

  field :order_id, type: String

  field :prepay_id, type: String
  field :wechat_transaction_id, type: String
  field :result_code, type: String
  field :err_code, type: String
  field :err_code_des, type: String
  field :trade_state_desc, type: String
  field :offline_paid, type: Boolean, default: false

  # status related attributes
  # deposit can have following status:
  # 1. not paid: course participate not created, or deposit created but pay_finished is false
  # 3. paying: pay_finished is true, but trade_state is not "SUCCESS"
  # 4. paid: trade_state is "SUCCESS"
  # whether pay process is finished. pay attention that this does not indicate that pay is success
  field :pay_finished, type: Boolean, default: false
  field :trade_state, type: String
  field :trade_state_updated_at, type: Integer
  field :expired_at, type: Integer, default: -1
  # similar as course participate
  field :renew_status, type: Boolean

  belongs_to :user
  has_many :bills
  has_many :red_packets

  def self.create_new(client)
    deposit_amount = BorrowSetting.first.try(:deposit) || 100
    deposit = self.create(# order_id: Util.random_str(32),
                          amount: deposit_amount)
    deposit.user = client
    deposit.save
    expired_at = Time.now + 1.days
    deposit.update_attributes({expired_at: expired_at.to_i})
    deposit
    # return cp.unifiedorder_interface(remote_ip, openid)
  end

  def paid
    return true if self.offline_paid == true
    if self.pay_finished == true && self.trade_state != "SUCCESS"
      self.orderquery()
    end
    return false if self.trade_state != "SUCCESS"
    return true
  end

  def unifiedorder_interface(remote_ip, openid)
    self.amount = BorrowSetting.first.try(:deposit) || 100
    self.save
    nonce_str = Util.random_str(32)
    order_id = Util.random_str(32)
    data = {
      "appid" => APPID,
      "mch_id" => MCH_ID,
      "nonce_str" => nonce_str,
      "body" => "绘本借阅押金",
      "out_trade_no" => order_id,
      "total_fee" => Rails.env == "production" ? (self.amount * 100).round.to_s : 1.to_s,
      "spbill_create_ip" => remote_ip,
      "notify_url" => NOTIFY_URL,
      "trade_type" => "JSAPI",
      "openid" => openid,
      "time_expire" => Time.at(self.expired_at + 600).strftime("%Y%m%d%H%M%S")
    }
    signature = Util.sign(data, APIKEY)
    data["sign"] = signature

    response = CourseParticipate.post("/pay/unifiedorder",
      :body => Util.hash_to_xml(data))

    # todo: handle error messages

    doc = Nokogiri::XML(response.body)
    prepay_id = doc.search('prepay_id').children[0].text
    self.update_attributes({prepay_id: prepay_id, order_id: order_id})
    Bill.create_online_deposit_pay_item(self)
  end

  def self.notify_callback(content)
    doc = Nokogiri::XML(content)
    order_id = doc.search('out_trade_no').children[0].text


    bill = Bill.where(order_id: order_id).first
    if bill.blank?
      logger.info "ERROR!!!!!!!!!!!!!!"
      logger.info "order is finished, but corresponding bill cannot be found"
      logger.info "ERROR!!!!!!!!!!!!!!"
      return
    end

    deposit = bill.deposit
    if deposit.nil?
      logger.info "ERROR!!!!!!!!!!!!!!"
      logger.info "order is finished, but corresponding course_participate cannot be found"
      logger.info "ERROR!!!!!!!!!!!!!!"
      return
    end
    success = doc.search('return_code').children[0].text
    logger.info "!!!!!!!!!!!!!!!!!!!"
    logger.info success
    if success != "SUCCESS"
      return nil
    else
      result_code = doc.search('result_code').children[0].text
      logger.info "!!!!!!!!!!!!!!!!!!!"
      logger.info result_code
      if result_code != "SUCCESS"
        err_code = doc.search('err_code').children[0].text
        err_code_des = doc.search('err_code_des').children[0].text
        deposit.update_attributes({
          trade_state: result_code,
          err_code: err_code,
          err_code_des: err_code_des
        })
      else
        wechat_transaction_id = doc.search('transaction_id').children[0].try(:text)
        logger.info "!!!!!!!!!!!!!!!!!!!"
        logger.info wechat_transaction_id
        deposit.update_attributes({
          trade_state: "SUCCESS",
          trade_state_desc: "",
          trade_state_updated_at: Time.now.to_i,
          wechat_transaction_id: wechat_transaction_id,
          pay_finished: true,
          expired_at: -1
        })
        bill.confirm_deposit_item
      end
    end
  end

  def get_pay_info
    retval = {
      "appId" => APPID,
      "timeStamp" => Time.now.to_i.to_s,
      "nonceStr" => Util.random_str(32),
      "package" => "prepay_id=" + self.prepay_id,
      "signType" => "MD5"
    }
    signature = Util.sign(retval, APIKEY)
    retval["sign"] = signature
    return retval
  end

  def renew
    self.update_attributes(
      {
        expired_at: (Time.now + 1.days).to_i,
        # order_id: Util.random_str(32),
        prepay_id: ""
      })
  end

  def orderquery
    self.update_attributes({renew_status: false})
    if self.order_id.blank?
      return nil
    end
    nonce_str = Util.random_str(32)
    data = {
      "appid" => APPID,
      "mch_id" => MCH_ID,
      "out_trade_no" => self.order_id,
      "nonce_str" => nonce_str,
      "sign_type" => "MD5"
    }
    signature = Util.sign(data, APIKEY)
    data["sign"] = signature
    response = CourseParticipate.post("/pay/orderquery",
      :body => Util.hash_to_xml(data))

    doc = Nokogiri::XML(response.body)
    success = doc.search('return_code').children[0].text
    if success != "SUCCESS"
      return nil
    else
      result_code = doc.search('result_code').children[0].text
      self.update_attributes({result_code: result_code})
      if result_code != "SUCCESS"
        err_code = doc.search('err_code').children[0].text
        err_code_des = doc.search('err_code_des').children[0].text
        self.update_attributes({
          err_code: err_code,
          err_code_des: err_code_des
        })
        retval = { success: false, err_code: err_code, err_code_des: err_code_des }
        return retval
      else
        trade_state = doc.search('trade_state').children[0].text
        trade_state_desc = doc.search('trade_state').children[0].text
        wechat_transaction_id = doc.search('transaction_id').children[0].try(:text)
        self.update_attributes({
          trade_state: trade_state,
          trade_state_updated_at: Time.now.to_i,
          trade_state_desc: trade_state_desc,
          wechat_transaction_id: wechat_transaction_id
        })
        if trade_state == "SUCCESS"
          self.update_attributes({pay_finished: true})
          bill = Bill.where(order_id: self.order_id).first
          bill.confirm_course_participate_item
        end
        retval = { success: true, trade_state: trade_state, trade_state_desc: trade_state_desc }
        return retval
      end
    end
  end

  # status related
  def need_order_query()
    return self.renew_status || (self.pay_finished == true && self.trade_state != "SUCCESS")
  end

  def is_expired
    return false if offline_paid == true
    if need_order_query
      self.orderquery()
    end
    self.trade_state != "SUCCESS" && self.expired_at < Time.now.to_i
  end

  def is_paying
    return false if offline_paid == true
    if self.need_order_query
      self.orderquery()
    end
    self.pay_finished == true && self.trade_state != "SUCCESS"
  end

  def is_success
    return true if offline_paid == true
    if self.need_order_query
      self.orderquery()
    end
    self.trade_state == "SUCCESS"
  end

  def refund(center=nil)
    self.update_attributes({pay_finished: false, offline_paid: false, trade_state: ""})
    # Bill.create_deposit_refund_item(center, self)
    nil
  end

  def status_str
    return "已缴纳" + self.amount.to_s + "元" if self.paid
    return "支付中" if self.is_paying
    return "当前未缴纳"
  end

  def offline_pay(center)
    self.update_attributes({offline_paid: true})
    Bill.create_offline_deposit_pay_item(center, self)
    nil
  end
end
