require "google/apis/calendar_v3"
require "google/api_client/client_secrets.rb"

class TeacherController < ApplicationController
  before_action :check_cookies_login, except: [:login, :checklogin]
  $has_logged =false
  def login
    #cookies.delete(:teacher)
    session.delete(:CF)
    if session[:CF].present?
      @teacher=Teacher.find_by(CF: session[:CF])
      redirect_to teacher_home_url
    end
  end

  def upgradepassword
    @teacher=Teacher.find_by(CF: session[:CF])
    @teacher.update(password: $passk)
    redirect_to teacher_home_url
  end

  def changepassword
    @teacher=Teacher.find_by(CF: session[:CF])
    pass=params[:old_password]
    $passk=params[:password]
    if(@teacher) && @teacher.password == pass
      PasswordMailer.email_confirm(@teacher).deliver_now
    else
      redirect_to teacher_login_url
      flash[:alert]= "password inserita errata"
    end
    pass=""
  end
  
  def home
    @teacher=Teacher.find_by(CF: session[:CF])
    @classrooms=Subject.where(CFprof: @teacher.CF).pluck(:class_code).uniq
    unless(@classrooms)
      flash[:alert]= "non ci sono classi per questo insegnante, contatta la segreteria"
    end
  end

  def checklogin
    @teacher = Teacher.find_by(mail: params[:mail])
    if @teacher && @teacher.password == params[:password]
      session[:CF]= @teacher.CF
      if @teacher.first_login == true
        @teacher.update(first_login: false)
        cookies[:teacher]=@teacher.CF
      end
      redirect_to teacher_home_url
      
    else
      redirect_to teacher_login_url
      flash[:alert] = 'Credenziali non valide.'
    end
  end

  def checklogout
    session.delete(:CF)
    session.delete(:teacher_code)
    redirect_to root_path
  end

  def profile
    @teacher = Teacher.find_by(CF: session[:CF])
  end

  def check_cookies_login
    unless session[:CF].present?
        redirect_to teacher_login_url, alert: "Effettua l'accesso per continuare."
    end
    
  end
  
  def classroom
    @teacher=Teacher.find_by(CF: session[:CF])
    @classname=params[:classroom]
    @subjects=Subject.where(CFprof: @teacher.CF, class_code: params[:classroom]).pluck(:name).uniq
  end

  def commitment
    @teacher=Teacher.find_by(CF: session[:CF])
    @teacher_true = Teacher.find_by(name: @teacher.name, surname: @teacher.surname, school_code: @teacher.school_code)
    @meeting = Meeting.where(CFprof: @teacher_true)
    $client_calendar= get_google_calendar_client(@teacher)
    #@calendar_list = $client_calendar.list_calendar_lists

    

    @event_list =$client_calendar.list_events('6fb8a61d5cfb51e60783c32a6eb22acfaf8de8c8126dc7dbabb7da7568a85cc7@group.calendar.google.com')
    #Controllo i meeting (se il mio server ne ha in più li metto su calendar, altrimenti li rimuovo da calendar):
    @meeting.each do |meet|

      if !@event_list.items.any?{ |event| event.summary == meet.title } 
        start_date = meet.date - 2.hour
        end_date = start_date + 1.hour
        event = Google::Apis::CalendarV3::Event.new({
          summary: meet.title,
          location: "Rome, italy",
          description: meet.link,
          start: {
            date_time: start_date.to_datetime.rfc3339,
            # date_time: '2019-09-07T09:00:00-07:00',
            time_zone: 'UTC',
          },
          end: {
            date_time: end_date.to_datetime.rfc3339,
            time_zone: 'UTC',
          },
          reminders: {
            use_default: false,
            overrides: [
              Google::Apis::CalendarV3::EventReminder.new(reminder_method:"popup", minutes: 10),
              Google::Apis::CalendarV3::EventReminder.new(reminder_method:"email", minutes: 20)
            ]
          },
          notification_settings: {
            notifications: [
                            {type: 'event_creation', method: 'email'},
                            {type: 'event_change', method: 'email'},
                            {type: 'event_cancellation', method: 'email'},
                            {type: 'event_response', method: 'email'}
                           ]
          }, 'primary': true
        })
        $client_calendar.insert_event('6fb8a61d5cfb51e60783c32a6eb22acfaf8de8c8126dc7dbabb7da7568a85cc7@group.calendar.google.com', event)
                 
      end 
    end       
    @event_list.items.each do |event|
      event.summary 
      puts event.summary.inspect
      if event.summary.include?("Meeting con ")
        if  !@meeting.any?{|meet| meet.title == event.summary}
          $client_calendar.delete_event('6fb8a61d5cfb51e60783c32a6eb22acfaf8de8c8126dc7dbabb7da7568a85cc7@group.calendar.google.com',event.id)
        end
      end
    end
    @commitments = Commitment.where(CFprof:@teacher_true, type: "Commitment" )
    @commitments.each do |commit| 
      if !@event_list.items.any?{|event| event.summary == commit.title}
        commit.delete
      end
    end
    @event_list.items.each do |event|

      if !event.summary.include?("Meeting con ")
        puts event.summary
        if  !@commitments.any?{|commit| commit.title == event.summary}
          puts event.summary
          start_time = event.start.date_time
          end_time =  event.end.date_time
          new_date = start_time
          time = end_time.hour - start_time.hour
          time = time.to_i
          for i in 1..time
            @commitment = Commitment.new(
              title: event.summary,
              date: new_date,
              type: 'Commitment',
              CFprof: @teacher_true.CF,
              school_code: @teacher_true.school_code)
            if @commitment
              @commitment.save
              #  puts("sas")
            end
            new_date += 1.hour
          end
        end
      end
    end  

  end

  def get_google_calendar_client(current_user)
    client = Google::Apis::CalendarV3::CalendarService.new
    return unless (current_user.present? && current_user.access_token.present? && current_user.refresh_token.present?)
    secrets = Google::APIClient::ClientSecrets.new({
      "web" => {
        "access_token" => current_user.access_token,
        "refresh_token" => current_user.refresh_token,
        "client_id" => ENV["GOOGLE_OAUTH_CLIENT_KEY"],
        "client_secret" => ENV["GOOGLE_OAUTH_CLIENT_SECRET"]
      }
    })
    begin
      client.authorization = secrets.to_authorization
      client.authorization.grant_type = "refresh_token"

      if !current_user.present?
        client.authorization.refresh!
        current_user.update_attributes(
          access_token: client.authorization.access_token,
          refresh_token: client.authorization.refresh_token,
          expires_at: client.authorization.expires_at.to_i
        )
      end
    rescue => e
      flash[:error] = 'Your token has been expired. Please login again with google.'
      redirect_to teacher_login_url
    end
    client
  end

  def managecommitment
    date=params[:date]
    hours=params[:hour].to_i
    title=params[:title]
    prof=params[:CFprof]
    start_date = DateTime.parse(date) - 2.hour
    end_date = start_date + hours.hour
    event = Google::Apis::CalendarV3::Event.new({
      summary: title,
      location: "Rome, italy",
      description: "",
      start: {
        date_time: start_date.to_datetime.rfc3339,
        # date_time: '2019-09-07T09:00:00-07:00',
        time_zone: 'UTC',
      },
      end: {
        date_time: end_date.to_datetime.rfc3339,
        time_zone: 'UTC',
      },
      reminders: {
        use_default: false,
        overrides: [
          Google::Apis::CalendarV3::EventReminder.new(reminder_method:"popup", minutes: 10),
          Google::Apis::CalendarV3::EventReminder.new(reminder_method:"email", minutes: 20)
        ]
      },
      notification_settings: {
        notifications: [
                        {type: 'event_creation', method: 'email'},
                        {type: 'event_change', method: 'email'},
                        {type: 'event_cancellation', method: 'email'},
                        {type: 'event_response', method: 'email'}
                       ]
      }, 'primary': true
    }) 
    # puts("mimomimo")
    if $client_calendar
      $client_calendar.insert_event('6fb8a61d5cfb51e60783c32a6eb22acfaf8de8c8126dc7dbabb7da7568a85cc7@group.calendar.google.com', event)
      # puts("ciao")
      flash[:notice] = 'Task was successfully added.'
    end
    # puts(event)
    # puts("cciao")
       # Utilizzo un oggetto DateTime per la data iniziale
    new_date = DateTime.parse(params[:date])
    # puts new_date
    num = params[:hour].to_i
    for i in 1..num
     @commitment = Commitment.new(
       title: params[:title],
       date: new_date,
       type: 'Commitment',
       CFprof: params[:CFprof],
       school_code: params[:school_code])
     if @commitment
       @commitment.save
      #  puts("sas")
     end
     new_date += 1.hour
    end      
    redirect_to teacher_commitment_url
  end
  
  def meeting
    @teacher=Teacher.find_by(CF: session[:CF])
    @meetings=Meeting.where(CFprof: @teacher.CF)
    token=generate_token(@teacher.name)
    room="ssarekde"
    @link_teacher="https://localhost:8000/#{room}?jwt=#{token}"

  end

  def generate_token(name)
      payload = {
        iss: 'localhost',
        room: name,
        exp: Time.now.to_i + 3600, # Scadenza del token (1 ora)
      }
      jwt = JWT.encode payload, 'la_tua_chiave_segreta', 'HS256'
      jwt
  end

  def requestmeeting
    @teacher=Teacher.find_by(CF: session[:CF])
    @classname=params[:classroom]
    @confirm=""
    if(params[:confirm].present?)
      @confirm="email inviata al genitore!"
      
    end
    @students= Student.where(student_class_code: @classname)
    
  end

  def insertmeeting
    @confirm=""  
    cfstudent=params[:CFstudent]
    student=Student.find_by(CF: cfstudent)
    teacher=Teacher.find_by(CF: params[:CFprof])
    cfparent=FamilyStudent.where(CFstudent: cfstudent).pluck(:CFfamily).uniq
    @parent_mail=Family.where(CF: cfparent).pluck(:mail).uniq
    text=params[:text]
    # puts("ciao")
    # puts(@parent_mail)
    # puts("ciaos")
    MeetingMailer.meeting_request(@parent_mail,text, student, teacher).deliver_now
    redirect_to teacher_requestmeeting_url(classroom: params[:class_code], confirm: "conferma")
  end

  def grade
    @teacher=Teacher.find_by(CF: session[:CF])
    @classname=params[:classroom]
    @subjects= Subject.where(CFprof: params[:CF], class_code: params[:classroom]).pluck(:name).uniq
    
    @students=Student.where(student_class_code: params[:classroom])
    @weekdays=[]
    @times=[]
    
    $subj = params[:subject]
    $weekd = params[:weekday]
    $tim = params[:time]
    
    if(params[:subject].present?)

      @subjects=Subject.where(CFprof: params[:CF], class_code: params[:classroom], name: params[:subject]).pluck(:name).uniq
      
      @weekdays=[["Select weekday", nil]]+Subject.where(CFprof: params[:CF], class_code: params[:classroom], name: params[:subject]).pluck(:weekday).uniq
      
      if(params[:weekday].present?)
        @weekdays=Subject.where(CFprof: params[:CF], class_code: params[:classroom], name: params[:subject], weekday: params[:weekday]).pluck(:weekday).uniq
        @times=[["Select school hour", nil]]+Subject.where(CFprof: params[:CF], class_code: params[:classroom], name: params[:subject], weekday: params[:weekday]).pluck(:time).uniq
        if(params[:time].present?)
          @times=Subject.where(CFprof: params[:CF], class_code: params[:classroom], name: params[:subject], weekday: params[:weekday], time: params[:time]).pluck(:time).uniq
        end
      end
    end
    @grades =  Grade.where(CFprof: params[:CF], class_code: params[:classroom])
  end

  def insertgrade

    day= Date.parse(params[:date]).strftime('%A').upcase
    if($weekd == day)
      puts params[:CFstudent]
      @grade=Grade.new(CFprof: params[:CFprof], CFstudent: params[:CFstudent].join , date: params[:date], value: params[:value], weekday: $weekd, time: $tim, subject_name: $subj, class_code: params[:class_code], school_code: params[:school_code])
      puts @grade.inspect
      if @grade
        @grade.save
        redirect_to teacher_grade_url(CF: params[:CFprof], classroom: params[:class_code])
      end
    else
      redirect_to teacher_grade_url(CF: params[:CFprof], classroom: params[:class_code])
    end
  end

  def absence
    @teacher=Teacher.find_by(CF: session[:CF])
    @classname=params[:classroom]
    @subjects=[["Subject", nil]]+Subject.where(CFprof: params[:CF], class_code: params[:classroom]).pluck(:name).uniq
    @students=Student.where(student_class_code: params[:classroom])
    @weekdays=[]
    @times=[]
    if(params[:subject].present?)
      @subjects=Subject.where(CFprof: params[:CF], class_code: params[:classroom], name: params[:subject]).pluck(:name).uniq
      @weekdays=[["Select weekday", nil]]+Subject.where(CFprof: params[:CF], class_code: params[:classroom], name: params[:subject]).pluck(:weekday).uniq
      if(params[:weekday].present?)
        @weekdays=Subject.where(CFprof: params[:CF], class_code: params[:classroom], name: params[:subject], weekday: params[:weekday]).pluck(:weekday).uniq
        e@tims=[["Select school hour", nil]]+Subject.where(CFprof: params[:CF], class_code: params[:classroom], name: params[:subject], weekday: params[:weekday]).pluck(:time).uniq
        if(params[:time].present?)
          @times=Subject.where(CFprof: params[:CF], class_code: params[:classroom], name: params[:subject], weekday: params[:weekday], time: params[:time]).pluck(:time).uniq
        end
      end
    end
    @absences =  Absence.where(CFprof: params[:CF], class_code: params[:classroom])
  end

  def insertabsence
    cfstudente=params[:CFstudent].join
    # puts(cfstudente)
    @absence=Absence.new(CFprof: params[:CFprof], CFstudent: cfstudente, date: params[:date], justified: params[:justified], weekday: params[:weekday], time: params[:time], subject_name: params[:subject_name], class_code: params[:class_code], school_code: params[:school_code])
    if @absence
      @absence.save
      redirect_to teacher_absence_url(CF: params[:CFprof], classroom: params[:class_code])
    end
  end

  def note
    @teacher=Teacher.find_by(CF: session[:CF])
    @students=Student.where(student_class_code: params[:classroom])
    @classname=params[:classroom]
    @notes=Note.where(CFprof: params[:CF])
  end
  
  def insertnote
    @note=Note.new(CFprof: params[:CFprof], CFstudent: params[:CFstudent], date: params[:date], description: params[:description], school_code: params[:school_code])
    if @note
      @note.save
      redirect_to teacher_note_url(CF: params[:CFprof], classroom: params[:classroom])
    end
  end

  def homework
    @teacher=Teacher.find_by(CF: session[:CF])
    @classname=params[:classroom]
    @subjects=[["Subject", nil]]+Subject.where(CFprof: params[:CF], class_code: params[:classroom]).pluck(:name).uniq
    @homeworks= Homework.where(CFprof: params[:CF], class_code: params[:classroom])
  end

  def managehomework
    @subjects=Subject.where(CFprof: params[:CFprof], class_code: params[:class_code], name: params[:subject_name]).first
    weekday=@subjects.weekday
    time=@subjects.time
    @homework=Homework.new(CFprof: params[:CFprof],delivered: params[:delivered], date: params[:date], text: params[:text], name: params[:name], weekday: weekday, time: time, subject_name: params[:subject_name], class_code: params[:class_code], school_code: params[:school_code])
    if @homework
      @homework.save
      redirect_to teacher_homework_url(CF: params[:CFprof], classroom: params[:class_code])
    end
  end

 def communication
  @teacher=Teacher.find_by(CF: params[:CF])
  @classname=params[:classroom]
  @communications=Communication.where(school_code: @teacher.school_code)
 end
end