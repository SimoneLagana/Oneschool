Rails.application.routes.draw do
  get 'school/home'
  get 'school/login'


  get 'oneschool/index'
  root "oneschool#index"

  #teacher
  get 'teacher/login', to: 'teacher#login', as: 'teacher_login'
  get 'teacher/home', to: 'teacher#home', as: 'teacher_home'
  get 'teacher/meeting', to: 'teacher#meeting', as: 'teacher_meeting'
  get 'teacher/grade', to: 'teacher#grade', as: 'teacher_grade'

  get 'teacher/profile', to: 'teacher#profile', as: 'teacher_profile'
  get 'teacher/classroom', to: 'teacher#ClassRoom', as: 'teacher_classroom'
  delete "teacher/checklogout", to: "teacher#checklogout", as: 'teacher_checklogout'
  post 'teacher/checklogin', to: 'teacher#checklogin', as: 'teacher_checklogin'
  post 'teacher/changepassword', to: 'teacher#changepassword', as: 'teacher_changepassword'
  #post 'teacher/accessclass', to: 'teacher#accessclass', as: 'teacher_accessclass'

  

  #student
  get 'student/login', to: 'student#login', as: 'student_login'
  get 'student/home', to: 'student#home', as: 'student_home'

  delete "student/checklogout", to: "student#checklogout", as: 'student_checklogout'
  post 'student/checklogin', to: 'student#checklogin', as: 'student_checklogin'


  #family
  get 'family/login', to: 'family#login', as: 'family_login'
  get 'family/home', to: 'family#home', as: 'family_home'

  delete "family/checklogout", to: "family#checklogout", as: 'family_checklogout'
  post 'family/checklogin', to: 'family#checklogin', as: 'family_checklogin'


#school_staff
get 'school_staff/login', to: 'school_staff#login', as: 'school_staff_login'
get 'school_staff/home', to: 'school_staff#home', as: 'school_staff_home'

delete "school_staff/checklogout", to: "school_staff#checklogout", as: 'school_staff_checklogout'
post 'school_staff/checklogin', to: 'school_staff#checklogin', as: 'school_staff_checklogin'

  

  get "/oneschool", to: "oneschool#index"

  #admin
  get "/admin/signup", to: "admin#signup"
  get "admin/manage", to: "admin#manage"
  post "/admin/create", to: "admin#create" 
  post "/admin/createSchool", to: "admin#create_school"
  post "/admin/createStaff", to: "admin#create_staff"
  post "/admin/editSchool", to: "admin#edit_school"
  post "/admin/updateSchool", to: "admin#update_school"
  delete "/admin/deleteSchool", to: "admin#delete_school", as: "admin_deleteschool"
  post "/admin/updateStaff", to: "admin#update_staff", as: "admin_updatestaff"
  delete "/admin/deleteStaff", to: "admin#delete_staff", as: "admin_deletestaff"

  delete "admin/checklogout", to: "admin#checklogout", as: 'admin_checklogout'
  post 'admin/checklogin', to: 'admin#checklogin', as: 'admin_checklogin'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # namespace :admin do
  #   resources :schools, only: [:new, :create, :destroy]
  # end
  # namespace :admin do
  #   resources :users
  # end
  
end
