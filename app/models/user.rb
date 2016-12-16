require 'open-uri'
class User

  include Mongoid::Document
  include Mongoid::Timestamps

  CLIENT = 1
  STAFF = 2
  ADMIN = 4

  BOY = 1
  GIRL = 2

  field :email, type: String
  field :mobile, type: String
  field :password, type: String
  field :name, type: String
  field :user_type, type: Integer, default: CLIENT
  field :email_verified, type: Boolean, default: false
  field :email_verify_code, type: String
  field :mobile_verified, type: Boolean, default: false
  field :mobile_verify_code, type: String
  field :password_verify_code, type: String
  field :auth_key, type: String

  # for staff
  NEW = 1
  NORMAL = 2
  LOCKED = 4
  field :center, type: String
  field :status, type: Integer

  # for client
  field :gender, type: Integer, default: -1  # 0 for male, 1 for female
  field :birthday, type: Date
  field :parent, type: String
  field :address, type: String
  field :created_by_staff, type: Boolean, default: false
  field :first_signin, type: Boolean, default: true

  # relationships specific for clients
  # belongs_to :client_center
  has_and_belongs_to_many :client_centers, class_name: "Center", inverse_of: :clients
  has_many :course_participates, class_name: "CourseParticipate", inverse_of: :client
  has_many :book_borrows, class_name: "BookBorrow", inverse_of: :client
  has_many :reviews, class_name: "Review", inverse_of: :client
  has_many :audit_reviews, class_name: "Review", inverse_of: :staff
  has_many :favorites
  has_many :messages, class_name: "Message", inverse_of: :client
  has_many :bills
  has_one :deposit

  # relationships specific for staff
  belongs_to :staff_center, class_name: "Center", inverse_of: :staffs
  has_many :announcements
  has_many :staff_logs

  has_one :avatar, class_name: "Material", inverse_of: :client

  scope :client, ->{ where(user_type: CLIENT) }
  scope :staff, ->{ any_of({user_type: STAFF}, {user_type: ADMIN}) }
  scope :admin, ->{ where(user_type: ADMIN) }
  scope :only_staff, ->{ where(user_type: STAFF) }

  def is_admin
    return self.user_type == ADMIN
  end

  def is_client
    return self.user_type == CLIENT
  end

  def self.create_user(user_type, mobile, created_by_staff = false, center = nil)
    # 1. check whether user exists?
    u = User.where(mobile: mobile).first
    if u.present? && user_type != u.type
      return ErrCode::OTHER_TYPE_USER_EXIST
    end
    if u.present? && u.mobile_verified
      return ErrCode::USER_EXIST
    elsif u.blank?
      u = User.create(user_type: user_type, mobile: mobile)
    end

    if user_type == CLIENT && created_by_staff == true
      u.update_attribute(:created_by_staff, created_by_staff)
      if center.present? || center.class == Center
        u.client_centers << center
      end
      u.first_signin = false
      u.save
    end

    # 2. generate random code and save
    code = ""
    6.times { code = code + rand(10).to_s }
    u.update_attribute(:mobile_verify_code, code)

    # 3. send message
    ret = Sms.send(mobile, code)
    # logger.info "AAAAAAAAAAAAAAAAAAA"
    # logger.info ret.inspect
    # logger.info "AAAAAAAAAAAAAAAAAAA"
    
    # 4. return user id
    { uid: u.id.to_s }
  end

  def self.find_by_auth_key(auth_key)
    info = Encryption.decrypt_auth_key(auth_key)
    uid = info.split(',')[0]
    User.where(id: uid).first
  end

  def self.signin_staff_mobile(mobile, password)
    user = User.only_staff.where(mobile: mobile).first
    return ErrCode::USER_NOT_EXIST if user.nil?
    return ErrCode::USER_NOT_VERIFIED if user.mobile_verified == false
    return ErrCode::WRONG_PASSWORD if Encryption.encrypt_password(password) != user.password
    return ErrCode::NO_CENTER if user.status == NEW
    return ErrCode::ACCOUNT_LOCKED if user.status == LOCKED
    auth_key = user.generate_auth_key
    user.update_attribute(:auth_key, auth_key)
    return { auth_key: auth_key }
  end

  def self.signin_staff(mobile, password)
    user = User.staff.where(mobile: mobile).first || User.admin.where(mobile: mobile).first
    return ErrCode::USER_NOT_EXIST if user.nil?
    return ErrCode::USER_NOT_VERIFIED if user.mobile_verified == false
    return ErrCode::WRONG_PASSWORD if Encryption.encrypt_password(password) != user.password
    return ErrCode::NO_CENTER if user.status == NEW
    return ErrCode::ACCOUNT_LOCKED if user.status == LOCKED
    auth_key = user.generate_auth_key
    user.update_attribute(:auth_key, auth_key)
    return { auth_key: auth_key }
  end

  def self.signin_user(mobile, password)
    user = User.client.where(mobile: mobile).first
    return ErrCode::USER_NOT_EXIST if user.nil?
    return ErrCode::USER_NOT_VERIFIED if user.mobile_verified == false
    return ErrCode::WRONG_PASSWORD if Encryption.encrypt_password(password) != user.password
    auth_key = user.generate_auth_key
    user.update_attribute(:auth_key, auth_key)
    return { auth_key: auth_key }
  end

  def self.signin_admin(mobile, password)
    user = User.admin.where(mobile: mobile).first
    return ErrCode::USER_NOT_EXIST if user.nil?
    return ErrCode::USER_NOT_VERIFIED if user.mobile_verified == false
    return ErrCode::WRONG_PASSWORD if Encryption.encrypt_password(password) != user.password
    auth_key = user.generate_auth_key
    user.update_attribute(:auth_key, auth_key)
    return { auth_key: auth_key }
  end

  def generate_auth_key
    info = "#{self.id.to_s},#{Time.now.to_i}"
    Encryption.encrypt_auth_key(info)
  end

  def verify_client(name, password, verify_code)
    if mobile_verify_code != verify_code
      return ErrCode::WRONG_VERIFY_CODE
    end
    self.update_attributes(name: name, mobile_verified: true, status: NEW, password: Encryption.encrypt_password(password))
    self.save
    nil
  end

  def verify_staff(name, center_name, password, verify_code)
    if mobile_verify_code != verify_code
      return ErrCode::WRONG_VERIFY_CODE
    end
    center = Center.where(name: center_name).first
    if center.nil?
      return ErrCode::CENTER_NOT_EXIST
    end
    self.update_attributes(name: name, mobile_verified: true, status: NEW, password: Encryption.encrypt_password(password))
    self.staff_center = center
    self.save
    nil
  end

  def forget_password
    if self.mobile_verified == false
      return ErrCode::USER_NOT_VERIFIED
    end

    # generate random code and save
    code = ""
    6.times { code = code + rand(10).to_s }
    self.update_attribute(:password_verify_code, code)

    # todo: send message
    ret = Sms.send(self.mobile, code)
    # logger.info "AAAAAAAAAAAAAAAAAAA"
    # logger.info ret.inspect
    # logger.info "AAAAAAAAAAAAAAAAAAA"

    { uid: self.id.to_s }
  end

  def verify_password_code(verify_code)
    if self.password_verify_code != verify_code
      return ErrCode::WRONG_VERIFY_CODE
    end
    nil
  end

  def set_password(password)
    self.update_attributes(password: Encryption.encrypt_password(password))
    nil
  end

  def reset_password(password, verify_code)
    if self.mobile_verified == false
      return ErrCode::USER_NOT_VERIFIED
    end

    if self.password_verify_code != verify_code
      return ErrCode::WRONG_VERIFY_CODE
    end
    self.update_attributes(password: Encryption.encrypt_password(password))
    nil
  end

  def change_password(old_password, new_password)
    return ErrCode::WRONG_PASSWORD if Encryption.encrypt_password(old_password) != self.password
    self.update_attributes(password: Encryption.encrypt_password(new_password))
    nil
  end

  def can_review_on(ele)
    if (ele.class == CourseInst)
      return self.course_participates.where(trade_state: "SUCCESS").map { |e| e.course_inst } .include? ele
    end
    if (ele.class == Book)
      return self.book_borrows.map { |e| e.book } .include? ele
    end
    return false
  end

  def review_on(ele)
    if (ele.class == CourseInst)
      review = self.reviews.where(course_inst: ele).first
      return review.present?
    end
    if (ele.class == Book)
      review = self.reviews.where(book: ele).first
      return review.present?
    end
    return false
  end

  def favorite_on(ele)
    if (ele.class == CourseInst)
      fav = self.favorites.where(course_inst: ele).first
      return fav.present? && fav.enabled
    end
    if (ele.class == Book)
      fav = self.favorites.where(book: ele).first
      return fav.present? && fav.enabled
    end
    return false
  end

  def is_staff
    return self.user_type == User::STAFF
  end

  def is_admin
    return self.user_type == User::ADMIN
  end

  def is_staff_or_admin
    return self.user_type == User::ADMIN || self.user_type == User::STAFF
  end

  def client_info
    {
      id: self.id.to_s,
      name: self.name,
      gender: self.gender,
      age: self.birthday.present? ? Date.today.year - self.birthday.year : nil,
      parent: self.parent,
      mobile: self.mobile,
      address: self.address
    }
  end

  def staff_info
    status_hash = {
      NEW => "新创建",
      LOCKED => "锁定中",
      NORMAL => "正常"
    }
    {
      id: self.id.to_s,
      name: self.name,
      mobile: self.mobile,
      center: self.staff_center.try(:name),
      status: status_hash[self.status]
    }
  end

  def birthday_str
    if self.birthday.present?
      return self.birthday.year.to_s + "-" + self.birthday.month.to_s + "-" + self.birthday.day.to_s
    else
      ""
    end
  end

  def self.genders_for_select(with_default = true)
    hash = { "男" => 0, "女" => 1 }
    if with_default
      hash["请选择"] = -1
    end
    hash 
  end

  def update_profile(profile)
    self.name = profile["name"]
    self.gender = profile["gender"].to_i
    self.parent = profile["parent"]
    self.address = profile["address"]
    if profile["birthday"].present?
      ary = profile["birthday"].split('-').map { |e| e.to_i }
      birthday = Time.mktime(ary[0], ary[1], ary[2])
      self.birthday = birthday
    end
    self.save
    nil
  end

  def get_avatar(server_id)
    filename = SecureRandom.uuid.to_s + ".jpg"
    save_path = "public/uploads/avatars/" + filename
    url_path = "/uploads/avatars/" + filename
    open(save_path, "wb") do |file|
      file << open("https://api.weixin.qq.com/cgi-bin/media/get?access_token=#{Weixin.get_access_token}&media_id=#{server_id}").read
    end
    if self.avatar.present?
      self.avatar.update_attributes({path: url_path})
    else
      Material.create_avatar(self, url_path)
    end
    nil
  end

  def update_first_signin
    cur_val = self.first_signin
    self.update_attributes({first_signin: false}) if cur_val
    cur_val
  end

  def has_expired_book
    self.book_borrows.select { |e| e.is_expired } .present?
  end

  def latefee_not_paid
    self.book_borrows.where(latefee_paid: false).map { |e| e.latefee } .sum > 0
  end

  def reach_max_borrow
    book_num = BorrowSetting.first.try(:book_num)
    if book_num.blank?
      return false
    else
      self.book_borrows.where(return_at: nil).count >= book_num
    end
  end

  def self.client_stats
    gender = {'男生' => 0, '女生' => 0, '不详' => 0}
    age = {'0-3岁' => 0, '3-6岁' => 0, '6-9岁' => 0, '9-12岁' => 0, '12-15岁' => 0, "其他及不详" => 0}
    User.client.each do |e|
      if e.gender == 0
        gender['男生'] += 1
      elsif e.gender == 1
        gender['女生'] += 1
      else
        gender['不详'] += 1
      end
      if e.birthday.blank?
        age["其他及不详"] += 1
      else
        birth_at = Time.mktime(e.birthday.year, e.birthday.month, e.birthday.day)
        if Time.now - 15.years > birth_at
          age["其他及不详"] += 1
        elsif Time.now - 12.years > birth_at
          age["12-15岁"] += 1
        elsif Time.now - 9.years > birth_at
          age["9-12岁"] += 1
        elsif Time.now - 6.years > birth_at
          age["6-9岁"] += 1
        elsif Time.now - 3.years > birth_at
          age["3-6岁"] += 1
        else
          age["0-3岁"] += 1
        end
      end
    end
    num = Statistic.where(center_id: nil, type: Statistic::CLIENT_NUM, :stat_date.gt => (Time.now - 10.weeks).to_i).asc(:stat_date).map { |e| e.value }
    num = num.each_with_index.map { |e, i| i % 7 == 0 ? e : nil } .select { |e| e }
    {
      gender: gender.to_a,
      age: age.to_a,
      num: num
    }
  end

  def latefee_amount
    self.book_borrows.where(latefee_paid: false).map { |e| e.latefee } .sum
  end

  def expired_books_num
    self.book_borrows.expired.length
  end

  def cur_books_num
      self.book_borrows.where(return_at: nil).count
  end

  def pay_latefee(center)
    amount = self.latefee_amount
    if amount > 0
      Bill.create_latefee_pay_item(center, self, amount)
    end
    self.book_borrows.where(latefee_paid: false).each do |bb|
      bb.pay_latefee
    end
    nil
  end

  def deposit_status_str
    self.deposit.present? ? self.deposit.status_str : "当前未缴纳"
  end

  def deposit_paid
    self.deposit.blank? ? false : self.deposit.paid
  end

  def pay_deposit(center)
    deposit = self.deposit || Deposit.create_new(self)
    deposit.offline_pay(center)
    nil
  end

  def refund_deposit(center)
    deposit = self.deposit || Deposit.create_new(self)
    deposit.refund(center)
    nil
  end
end
