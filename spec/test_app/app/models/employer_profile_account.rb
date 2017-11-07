class EmployerProfileAccount
  include Mongoid::Document
  #include SetCurrentUser
  include Mongoid::Timestamps
  #include AASM
  include EmployerProfileAccountConcern
end
