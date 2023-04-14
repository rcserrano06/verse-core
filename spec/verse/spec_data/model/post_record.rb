# frozen_string_literal: true

class PostRecord < Verse::Model::Record::Base
  self.record_root_path       = ""
  self.repositories_root_path = ""

  belongs_to :user
  has_many :comments

  field :id, primary: true, type: Integer

  field :user_id

  field :title, type: String
  field :content, type: String
end
