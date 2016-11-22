class BookBorrow

  include Mongoid::Document
  include Mongoid::Timestamps

  NORMAL = 1
  LOST = 2

  field :status, type: Integer, default: NORMAL
  field :borrow_at, type: Integer
  field :return_at, type: Integer
  field :renew_at, type: Array

  belongs_to :book_inst
  belongs_to :book
  belongs_to :client, class_name: "User", inverse_of: :book_borrows


  def back
  	self.update_attributes({return_at: Time.now.to_i})
  end

  def review
    self.client.reviews.where(book_id: self.book.id).first
  end

  def is_expired
    borrow_duration = BorrowSetting.first.try(:borrow_duration)
    if borrow_duration.blank?
      return false
    else
      return self.return_at.blank? && Time.now.to_i - borrow_duration.days.to_i > self.borrow_at
    end
  end

  def return_class
    if self.is_expired
      return "overtime"
    end
    if self.return_at.blank?
      return "unreturn"
    end
  end

  def return_status_str
    if self.is_expired
      return "已逾期，联系电话 " + self.client.mobile
    end
    return self.return_at.present? ? Time.at(self.return_at).strftime("%Y-%m-%d %H:%M") : "暂未归还"
  end
end