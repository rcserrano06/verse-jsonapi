# frozen_string_literal: true

class UserRecord < Verse::Model::Record::Base
  field :id, primary: true, type: Integer
  field :name, type: String
  field :age, type: Integer

  has_many :posts
  has_many :comments
  has_one  :account
end

UserRepository = Class.new(Verse::Model::InMemory::Repository)

class PostRecord < Verse::Model::Record::Base
  field :id, primary: true, type: Integer

  field :user_id, visible: false

  field :title, type: String
  field :content, type: String

  field :secret_field, type: String, visible: false

  belongs_to :user, foreign_key: :user_id
  belongs_to :category, foreign_key: :category_name

  has_many :comments
end

PostRepository = Class.new(Verse::Model::InMemory::Repository)

class CommentRecord < Verse::Model::Record::Base
  field :id, primary: true

  field :user_id
  field :post_id

  field :content, type: String

  belongs_to :user, foreign_key: :user_id
  belongs_to :post, foreign_key: :post_id
end

CommentRepository = Class.new(Verse::Model::InMemory::Repository)

# non id primary key test.
class CategoryRecord < Verse::Model::Record::Base
  field :name, primary: true

  has_many :posts, foreign_key: :category_name
end

CategoryRepository = Class.new(Verse::Model::InMemory::Repository)

# UUID test record for allow_id functionality
class UuidRecord < Verse::Model::Record::Base
  field :id, primary: true, type: String
  field :name, type: String
  field :description, type: String
end

UuidRepository = Class.new(Verse::Model::InMemory::Repository)
