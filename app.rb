class App < Sinatra::Base
	enable :sessions
	

	get '/' do
		slim(:index)
	end

	post '/login' do 
		db = SQLite3::Database.new("db/Contact_list.sqlite") 
		username = params["username"] 
		password = params["password"]
		password_crypted = db.execute("SELECT password_digest FROM accounts WHERE username=?", username)
		if password_crypted == []
			session[:message] = "User does not exist"
			redirect("/error")
		else
			password_crypted = password_crypted[0][0] 
			password_digest = BCrypt::Password.new(password_crypted) 
		end
		if password_digest == password
			result = db.execute("SELECT id FROM accounts WHERE username=?", [username]) 
			session[:id] = result[0][0] 
		end
		redirect('/contacts')
	end

	get '/create' do
		slim(:create)
	end

	get '/contacts' do
		db = SQLite3::Database.new("db/Contact_list.sqlite")
		if session[:id] 
			id=session[:id].to_i
			contacts = db.execute("SELECT id,username FROM accounts WHERE id IN (SELECT user2_id FROM contacts WHERE user1_id = ?) OR id IN (SELECT user1_id FROM contacts WHERE user2_id = ?)",[id,id])
			slim(:contacts, locals:{contacts:contacts})
		else
			session[:message] = "You are not logged in"
			redirect("/error")
		end
	end

	get '/register' do
		slim(:register)
	end

	post '/register' do
		db = SQLite3::Database.new("db/Contact_list.sqlite")
		username = params["username"] 
		password = params["password"]
		confirm = params["password2"]
		if confirm == password
			begin
				password_digest = BCrypt::Password.create(password)
				db.execute("INSERT INTO accounts(username, password_digest) VALUES(? , ?) ", [username, password_digest])
				redirect('/')
			rescue SQLite3::ConstraintException 
				session[:message] = "Username is not available"
				redirect("/error")
			end
		else
			session[:message] = "Password does not match"
			redirect("/error")
		end
	end

	post '/create' do
		unless session[:id]
			session[:message] = "You are not logged in"
			redirect("/error")
		end
		db = SQLite3::Database.new("db/Contact_list.sqlite")
		content = params["content"]
		begin
			db.execute("INSERT INTO contacts(user1_id,user2_id) VALUES((SELECT id FROM accounts WHERE username = ?),?)", [content,session[:id]])
		rescue SQLite3::ConstraintException 
			session[:message] = "Username does not exist"
			redirect("/error")
		end
		redirect('/contacts')
	end

	post '/delete/:id' do
		db = SQLite3::Database.new("db/Contact_list.sqlite")
		id1 = params[:id]
		id2 = session[:id]
		db.execute("DELETE FROM contacts WHERE (user1_id=? AND user2_id=?) OR (user2_id=? AND user1_id=?)", [id1, id2, id2, id1])
		redirect('/contacts')
	end

	get '/update/:id' do
		db = SQLite3::Database.new("db/Contact_list.sqlite")
		id = params[:id] 
		result = db.execute("SELECT * FROM contacts WHERE id=?", id)
		if result[0][1].to_i == session[:id].to_i 
			slim(:update, locals:{result:result})
		else
			session[:message] = "Forbidden"	
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

	post '/logout' do 
		session[:login] = false
		session[:id] = nil
		redirect('/')
	end

	get '/error' do
		slim(:error, locals:{msg:session[:message]})
	end
end           
          
