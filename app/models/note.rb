class Note < ApplicationRecord
    belongs_to :users, foreign_key: 'CFprof', primary_key: 'CF', class_name: "User"
    belongs_to :users, foreign_key: 'CFstudent', primary_key: 'CF', class_name: "User"
end

