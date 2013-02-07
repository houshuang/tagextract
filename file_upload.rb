# encoding: utf-8

require 'rubygems'
require 'haml'
require 'slim'
require 'sinatra/base'

require 'tempfile'
require 'tag-extract'

# only for development
require "sinatra/reloader"


class FileUpload < Sinatra::Base
  configure do
    enable :static
    enable :sessions
    configure :development do
      register Sinatra::Reloader
    end

    set :views,  File.join(File.dirname(__FILE__), 'views')
    set :public_folder, File.join(File.dirname(__FILE__), 'public')
    set :files,  File.join(settings.public_folder, 'files/')
  end

  helpers do
    def flash(message = '')
      session[:flash] = message
    end
  end

  not_found do
    haml '404'
  end

  error do
    haml "Error (#{request.env['sinatra.error']})"
  end

  get '/' do
    @files = Dir.entries(settings.files) - ['.', '..']

    @flash = session[:flash]
    session[:flash] = nil

    slim :index
  end

  post '/upload' do
    if params[:file]
      filename = params[:file][:filename]
      file = params[:file][:tempfile]
      fname = Dir::Tmpname.make_tmpname("", nil).to_s
      path = settings.files + fname
      File.open(path, 'wb') {|f| f.write file.read }

      flash 'Uploaded successfully'
    else
      flash 'You have to choose a file'
    end

    redirect "/view/#{fname}"
  end

  get '/view/:file' do
    # check if file has been uploaded
    path = settings.files + params[:file]
    unless File.exists?(path)
      session[:flash] = "ID not found"
      redirect '/'
    end

    # process file
    a = File.read(path)
    tagextract= TagExtract.new(a)
   @html = tagextract.to_html
    File.write(path+".taskpaper", tagextract.to_taskpaper)
    tagextract.to_scrivener(path+".scrivener.zip")
    # display (needs to be pimped)
    @fname = params[:file]
    Slim::Engine.set_default_options :pretty => true, :sort_attrs => false

    slim :show
  end


end

