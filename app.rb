class App < Sinatra::Base
	enable :sessions



	# a href -> get -> html ->  form -> post /action -> redirect -> get


	get '/' do
		slim(:index) # index.slim
	end

	post '/login' do # Fångar in formuläret från index.slim 
		db = SQLite3::Database.new("db/Contact_list.sqlite") #Länka SQLITE
		username = params["username"] # Hämtad från register.slim, input med name="username"
		password = params["password"]
		password_crypted = db.execute("SELECT password_digest FROM accounts WHERE username=?", username) #Kryptera lösenord till databasen
		if password_crypted == []
			password_digest = nil
		else
			password_crypted = password_crypted[0][0] # första värdet, kollar på username, andra värden är password
			byebug
			password_digest = BCrypt::Password.new(password_crypted) # "Dekryptar"
		end
		if password_digest == password # om lösenordet matchar
			result = db.execute("SELECT id FROM accounts WHERE username=?", [username]) #Hämta ID från konton
			session[:id] = result[0][0] # id
			session[:login] = true # Är inloggad
		else
			session[:login] = false # Är INTE inloggad
		end
		redirect('/contacts')
	end

	get '/create' do
		slim(:create)
	end

	get '/contacts' do
		db = SQLite3::Database.new("db/Contact_list.sqlite") #Länka SQLITE
		if session[:login] == true #Om man har loggat in
			contact = db.execute("SELECT * FROM contacts WHERE account_id=?", session[:id].to_i)
			slim(:contacts, locals:{contacts:contact}) #contacts.slim, tar variablen "contact" till contacts.slim.
		else
			session[:message] = "You are not logged in"
			redirect("/error")# error.slim och skickar en variable "msg" till slim, variablen är session[:message]
		end
	end

	get '/register' do
		slim(:register) # register.slim
	end

	post '/register' do
		db = SQLite3::Database.new("db/Contact_list.sqlite") #Länka SQLITE
		username = params["username"]  # Hämtad från register.slim, input med name="username"
		password = params["password"]
		confirm = params["password2"]
		if confirm == password
			begin
				password_digest = BCrypt::Password.create(password) #Kryptera
				db.execute("INSERT INTO accounts(username, password_digest) VALUES(? , ?) ", [username, password_digest]) #Stoppa in i databasen
				redirect('/') #a href="/"
			rescue SQLite3::ConstraintException #Rescue om username redan finns
				session[:message] = "Username is not available"
				redirect("/error")
			end
		else
			session[:message] = "Password does not match"
			redirect("/error")
		end
	end

	post '/create' do
		db = SQLite3::Database.new("db/Contact_list.sqlite")
		content = params["content"]
		begin
			db.execute("INSERT INTO contacts(account_id,msg) VALUES(?,?)", [session[:id],content])
		rescue SQLite3::ConstraintException # Någon anledning kan skapa contacts utan att logga in. fixar bugfix
			session[:message] = "You are not logged in"
			redirect("/error")
		end
		redirect('/contacts')
	end

	post '/delete/:id' do
		db = SQLite3::Database.new("db/Contact_list.sqlite")
		id = params[:id]
		db.execute("DELETE FROM contacts WHERE id=?",id)
		redirect('/contacts')
	end

	get '/update/:id' do
		db = SQLite3::Database.new("db/Contact_list.sqlite")
		id = params[:id] # Hämtar från routen på "get '/update/{:id}'"
		result = db.execute("SELECT * FROM contacts WHERE id=?", id)
		if result[0][1].to_i == session[:id].to_i #Om man ändrar på route så kan man inte gå in i andras kontons contacts och ändra. så den ger en check om du har tillgång till contact innan du kan uppdatera
			slim(:update, locals:{result:result})
		else
			session[:message] = "Forbidden"	#Om du inte har tillgång, redirect till error som ger texten "Forbidden"
			redirect("/error")
		end
	end

	post '/update/:id' do
		db = SQLite3::Database.new("db/Contact_list.sqlite")
		id = params[:id].to_i
		new_contact = params["content"]
		db.execute("UPDATE contacts SET msg=? WHERE id=?", [new_contact, id])
		redirect('/contacts')
	end

	post '/logout' do #Loggar ut och tar bort sessions
		session[:login] = false
		session[:id] = nil
		redirect('/')
	end

	get '/error' do
		slim(:error, locals:{msg:session[:message]})
	end
end           
          
