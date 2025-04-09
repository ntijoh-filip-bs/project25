require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/activerecord'
require 'sinatra/flash'
require 'sinatra/multi_route'
require 'sinatra/namespace'
require 'slim'
require 'bcrypt'
Dir[File.join(__dir__, 'models', '*.rb')].each { |file| require_relative file } # Ladda alla modeller

# Konfiguration för databasen
set :database, { adapter: 'sqlite3', database: 'db/data.db' }
set :public_folder, 'public'
set :uploads_folder, File.join(settings.public_folder, 'uploads')

# Skapa uploads-mapp om den inte finns
Dir.mkdir(settings.uploads_folder) unless Dir.exist?(settings.uploads_folder)

enable :sessions

helpers do
   # Kontrollerar om en användare är inloggad
  def logged_in?
    !session[:user_id].nil?
  end

  # Hämtar nuvarande inloggad användare
  def current_user
    @current_user ||= User.find(session[:user_id]) if logged_in?
  end

  # Kontrollerar om nuvarande användare är admin
  def admin?
    current_user && current_user.admin?
  end

   # Kortar ner text med avslutning om den är för lång
  def truncate(text, length: 100, omission: "...")
    return if text.nil?
    text.length > length ? "#{text[0...length]}#{omission}" : text
  end
end

# Filter som körs före animal-routes
before '/animals*' do
  unless logged_in?
    flash[:error] = "You must be logged in to access this page."
    redirect '/login'
  end
end

# Skydd för redigering av djur
before '/animals/:id/edit' do
  @animal = Animal.find(params[:id])
  unless current_user == @animal.user || admin?
    flash[:error] = "You are not authorized to perform this action."
    redirect '/animals'
  end
end

# Skydd för borttagning av djur
before '/animals/:id/delete' do
  @animal = Animal.find(params[:id])
  unless current_user == @animal.user || admin?
    flash[:error] = "You are not authorized to perform this action."
    redirect '/animals'
  end
end

# Skydd för admin-routes
before '/admin/users*' do
  unless admin?
    flash[:error] = "Admin access required"
    redirect '/'
  end
end

# Startsida - visar senast uppladdade djur  
get '/' do
  @recent_animals = Animal.order(created_at: :desc).limit(4)
  slim :index
end

# Registreringsformulär
get '/register' do
  slim :'auth/register'
end

# Hanterar användarregistrering
post '/register' do
  user = User.new(
    username: params[:username],
    password: params[:password]
  )
  
  if user.save
    flash[:success] = "Registration successful!"
    redirect '/login'
  else
    flash[:error] = "Registration failed: #{user.errors.full_messages.join(', ')}"
    redirect '/register'
  end
end

# Inloggningsformulär
get '/login' do
  slim :'auth/login'
end

post '/login' do
  user = User.find_by(username: params[:username])
  
  if user && user.authenticate(params[:password])
    session[:user_id] = user.id
    flash[:success] = "Logged in successfully!"
    redirect '/'
  else
    flash[:error] = "Invalid username or password."
    redirect '/login'
  end
end

# Utloggning
get '/logout' do
  session.clear
  flash[:success] = "Logged out"
  redirect '/'
end

# Lista alla djur
get '/animals' do
  @animals = Animal.all
  slim :'animals/index'
end

# Formulär för nytt djur
get '/animals/new' do
  slim :'animals/new'
end

# Visa specifikt djur
get '/animals/:id' do
  @animal = Animal.find(params[:id])
  slim :'animals/show'
end

# Hanterar uppladdning av nytt djur
post '/animals' do
  filename = nil

   # Validera och hantera uppladdad bild
  if params[:image] && params[:image][:tempfile]
    allowed_extensions = ['.jpg', '.jpeg', '.png']
    ext = File.extname(params[:image][:filename]).downcase
    unless allowed_extensions.include?(ext)
      flash[:error] = "Only JPG/PNG images are allowed"
      redirect '/animals/new'
    end
    
    # Generera unikt filnamn och spara bild
    filename = SecureRandom.hex(8) + ext
    filepath = File.join(settings.uploads_folder, filename)

    File.open(filepath, 'wb') { |f| f.write(params[:image][:tempfile].read) }
  end

  # Skapa nytt djurobjekt
  animal = Animal.new(
    name: params[:name],
    description: params[:description],
    price: params[:price],
    image_filename: filename,
    user_id: current_user.id
  )

  if animal.save
    flash[:success] = "Animal uploaded successfully!"
    redirect '/animals'
  else
    # Rensa uppladdad bild om sparandet misslyckades
    File.delete(filepath) if filename && File.exist?(filepath)
    flash[:error] = "Error: #{animal.errors.full_messages.join(', ')}"
    redir
  end
end

# Redigeringsformulär för djur
get '/animals/:id/edit' do
  @animal = Animal.find(params[:id])
  slim :'animals/edit'
end

# Hanterar uppdatering av djur
put '/animals/:id' do
  @animal = Animal.find(params[:id])
  
  update_data = {
    name: params[:name],
    description: params[:description],
    price: params[:price]
  }
  
  # Hantera ny bild om uppladdad
  if params[:image] && params[:image][:tempfile]
    # Ta bort gammal bild om den finns
    if @animal.image_filename
      old_file = File.join(settings.uploads_folder, @animal.image_filename)
      File.delete(old_file) if File.exist?(old_file)
    end

     # Spara ny bild
    ext = File.extname(params[:image][:filename]).downcase
    filename = SecureRandom.hex(8) + ext
    filepath = File.join(settings.uploads_folder, filename)
    File.open(filepath, 'wb') { |f| f.write(params[:image][:tempfile].read) }
    
    update_data[:image_filename] = filename
  end
  
  if @animal.update(update_data)
    flash[:success] = "Animal updated successfully!"
    redirect "/animals/#{@animal.id}"
  else
    flash[:error] = "Error: #{@animal.errors.full_messages.join(', ')}"
    redirect "/animals/#{@animal.id}/edit"
  end
end

# Hanterar borttagning av djur
delete '/animals/:id' do
  animal = Animal.find(params[:id])
  animal.destroy
  flash[:success] = "Animal deleted successfully!"
  redirect '/animals'
end

# Användarprofil med egna uppladdade djur
get '/profile' do
  @user = current_user
  @animals = @user.animals
  slim :'users/profile'
end

# Admin: Lista alla användare
get '/admin/users' do
  @users = User.all
  slim :'admin/users/index'
end

# Admin: Visa användardetaljer
get '/admin/users/:id' do
  @user = User.find(params[:id])
  slim :'admin/users/show'
end

# Admin: Redigeringsformulär för användare
get '/admin/users/:id/edit' do
  @user = User.find(params[:id])
  slim :'admin/users/edit'
end

# Admin: Uppdatera användare
put '/admin/users/:id' do
  user = User.find(params[:id])
  
  if user.update(user_params)
    flash[:success] = "User updated successfully"
    redirect "/admin/users/#{user.id}"
  else
    flash[:error] = "Update failed: #{user.errors.full_messages.join(', ')}"
    redirect "/admin/users/#{user.id}/edit"
  end
end

# Admin: Radera användare
delete '/admin/users/:id' do
  user = User.find(params[:id])
  
  if user.can_be_managed_by?(current_user)
    user.destroy
    flash[:success] = "User deleted successfully"
  else
    flash[:error] = "Cannot delete this user"
  end
  
  redirect '/admin/users'
end

private

# Filtrera tillåtna användarparametrar
def user_params
  params.select { |k| %w[username admin].include?(k) }
end