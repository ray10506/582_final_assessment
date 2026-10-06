from flask import Flask 
# from flask_mysqldb import MySQL

# database = MySQL()

def create_app():
    app = Flask(__name__)
    
    from project.view import bp as main_bp
    app.register_blueprint(main_bp)

    # # below is the setup for the database
    # # you will need to configure these attributes yourself
    # app.config['MYSQL_HOST'] = '127.0.0.1' # dont change
    # app.config['MYSQL_PORT'] = 3307 # dont change
    # app.config['MYSQL_USER'] = 'root' # dont change
    # ## IMPORTANT: CHANGE THIS TO YOUR MYSQL PASSWORD
    # app.config['MYSQL_PASSWORD'] = 'ray10506' # change to match your mysql password
    # app.config['MYSQL_DB'] = 'todo_model' # change to match your desired database name
    
    # app.config['MYSQL_CURSORCLASS'] = 'DictCursor' # dont change/ optional

    # # initialize the database connection
    # database.init_app(app)
    
    return app