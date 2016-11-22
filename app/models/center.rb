class Center

  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :address, type: String
  field :lat, type: String
  field :lng, type: String
  field :desc, type: String
  field :available, type: Boolean

  has_one :photo, class_name: "Material", inverse_of: :center_photo
  has_many :course_insts
  has_many :books
  has_many :announcements
  has_many :staffs, class_name: "User", inverse_of: :staff_center

  has_many :out_transfers, class_name: "Transfer", inverse_of: "out_center"
  has_many :in_transfers, class_name: "Transfer", inverse_of: "in_center"

  has_many :feeds
  has_many :statistics

  has_and_belongs_to_many :clients, class_name: "User", inverse_of: :client_centers

  def self.create_center(center_info)
    center = Center.create(
      name: center_info[:name],
      address: center_info[:address],
      desc: center_info[:desc],
      available: center_info[:available],
      lat: center_info[:lat],
      lng: center_info[:lng]
    )
    { center_id: center.id.to_s }
  end

  def self.centers_for_select
    hash = { }
    Center.all.each do |c|
      hash[c.name] = c.id.to_s
    end
    hash 
  end

  def staffs_desc
    if self.staffs.length == 0
      "无"
    elsif self.staffs.length == 1
      self.staffs.first.name
    else
      self.staffs.first.name + "等" + self.staffs.length.to_s + "人"
    end
  end

  def books_desc
    total_stock = 0
    self.books.each { |e| total_stock = total_stock + e.stock }
    self.books.length.to_s + "种/" + total_stock.to_s + "本"
  end

  def courses_desc
    self.course_insts.length.to_s + "门"
  end

  def center_info
    {
      id: self.id.to_s,
      name: self.name,
      address: self.address,
      staffs_desc: self.staffs_desc,
      books_desc: self.books_desc,
      courses_desc: self.courses_desc,
      available: self.available
    }
  end

  def set_available(available)
    self.update_attribute(:available, available == true)
    nil
  end

  def update_info(center_info)
    self.update_attributes(
      {
        name: center_info["name"],
        address: center_info["address"],
        desc: center_info["desc"],
        lat: center_info["lat"],
        lng: center_info["lng"]
      }
    )
    nil
  end

  def client_stats
    gender = {'男生' => 0, '女生' => 0, '不详' => 0}
    age = {'0-3岁' => 0, '3-6岁' => 0, '6-9岁' => 0, '9-12岁' => 0, '12-15岁' => 0, "其他及不详" => 0}
    self.clients.each do |e|
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
    {
      gender: gender.to_a,
      age: age.to_a,
      num: []
    }
  end

  def calculate_daily_stats
    date = Date.today - 1.days
    stat_date = Time.mktime(date.year, date.month, date.day).to_i
    # client number
    if self.statistics.where(type: Statistic::CLIENT_NUM, stat_date: stat_date).blank?
      self.statistics.create(type: Statistic::CLIENT_NUM, stat_date: stat_date, value: self.clients.count)
    end
    # course signup number, income, and allowance
    signup_num = 0
    income = 0
    allowance = 0
    self.course_insts.each do |e|
      cps = e.course_participates.where(:trade_state => "SUCCESS",
                                        :trade_state_updated_at.gt => stat_date).length
      signup_num += cps.length
      cps.each do |cp|
        income += cp.price_pay || 0
        allowance += e.price - e.price_pay
      end
    end
    if self.statistics.create(type: Statistic::COURSE_SIGNUP_NUM, stat_date: stat_date).blank?
      self.statistics.create(type: Statistic::COURSE_SIGNUP_NUM, stat_date: stat_date, value: signup_num)
    end
    if self.statistics.create(type: Statistic::INCOME, stat_date: stat_date).blank?
      self.statistics.create(type: Statistic::INCOME, stat_date: stat_date, value: income)
    end
    if self.statistics.create(type: Statistic::ALLOWANCE, stat_date: stat_date).blank?
      self.statistics.create(type: Statistic::ALLOWANCE, stat_date: stat_date, value: allowance)
    end
    # borrow number, stock, and on shelf
    borrow_num = 0
    stock = 0
    off_shelf = 0
    self.books.each do |b|
      borrow_num += b.book_borrows.where(:borrow_at.gt => stat_date).length
      off_shelf += b.book_borrows.where(status: BookBorrow::NORMAL, return_at: nil).length
      stock += b.stock
    end
    if self.statistics.create(type: Statistic::BORROW_NUM, stat_date: stat_date).blank?
      self.statistics.create(type: Statistic::BORROW_NUM, stat_date: stat_date, value: borrow_num)
    end
    if self.statistics.create(type: Statistic::STOCK, stat_date: stat_date).blank?
      self.statistics.create(type: Statistic::STOCK, stat_date: stat_date, value: stock)
    end
    if self.statistics.create(type: Statistic::ON_SHELF, stat_date: stat_date).blank?
      self.statistics.create(type: Statistic::ON_SHELF, stat_date: stat_date, value: stock - off_shelf)
    end
  end
end