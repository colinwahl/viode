class User < ActiveRecord::Base
  mount_uploader :avatar, AvatarUploader
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :trackable, :validatable

  attr_accessor :login
  enum role: [:user, :admin, :moderator, :banned]

  has_many :answers, -> { where(anonymous: false) }, foreign_key: :author_id, dependent: :destroy
  has_many :questions, -> { where(anonymous: false) }, foreign_key: :author_id, dependent: :destroy
  has_many :subscriptions, foreign_key: :subscriber_id, dependent: :destroy

  has_reputation :answer_points, source: { reputation: :votes, of: :answers }
  has_reputation :question_points, source: { reputation: :votes, of: :questions }
  has_reputation :points, source: [{ reputation: :answer_points }, { reputation: :question_points }]

  validates :bio, length: { maximum: 400 }
  validates :fullname, length: { in: 2..90 }, allow_blank: true
  validates :username, length: { in: 3..20 },
            format: { with: /\A\w+\z/, message: 'can contain only letters, numbers and underscore' }
  validates :username, presence: true, uniqueness: { case_sensitive: false }

  def to_param
    username
  end

  def subscribe_to(subscribable)
    subscriptions.create(subscribable: subscribable) unless subscribed_to?(subscribable)
  end

  def unsubscribe_from(subscribable)
    subscriptions.where(
      subscribable_id: subscribable.id,
      subscribable_type: subscribable.class
    ).destroy_all if subscribed_to?(subscribable)
  end

  def subscribed_to?(subscribable)
    subscriptions.where(
      subscribable_id: subscribable.id,
      subscribable_type: subscribable.class
    ).any?
  end

  private

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions.to_h).where(["lower(username) = :value OR lower(email) = :value", { value: login.downcase }]).first
    else
      where(conditions.to_h).first
    end
  end
end
