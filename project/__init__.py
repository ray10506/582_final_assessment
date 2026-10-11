from flask import Flask
from flask_login import LoginManager
from flask_mysqldb import MySQL

database = MySQL()
login_manager = LoginManager()

def create_app():
    app = Flask(__name__)
    
    from project.views import bp as main_bp
    app.register_blueprint(main_bp)

    # below is the setup for the database
    # you will need to configure these attributes yourself
    app.config['MYSQL_HOST'] = '127.0.0.1' # dont change
    app.config['MYSQL_PORT'] = 3307 # dont change
    app.config['MYSQL_USER'] = 'root' # dont change
    ## IMPORTANT: CHANGE THIS TO YOUR MYSQL PASSWORD
    app.config['MYSQL_PASSWORD'] = 'ray10506' # change to match your mysql password
    app.config['MYSQL_DB'] = 'honestdrive' # change to match your desired database name
    
    app.config['MYSQL_CURSORCLASS'] = 'DictCursor' # dont change/ optional
    app.config['SECRET_KEY'] = '884056c2c746a13c9aebd0f064b0c631d224502c7bb6557e86ad832f8f02f9ca' # for Flask-WTF 的 CSRF, dont change/ optional

    # initialize the database connection
    database.init_app(app)

    login_manager.init_app(app)
    login_manager.login_view = 'main.login'  # redirect to login page if not logged in

    @login_manager.user_loader
    def load_user(user_id):
      from project.models import users
      user = users.get(user_id)
      return user if user and user.is_active else None
    
    return app