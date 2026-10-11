from flask_wtf import FlaskForm
from wtforms import SubmitField, StringField, PasswordField, RadioField
from wtforms.validators import DataRequired, Email, Length, EqualTo

class LoginForm(FlaskForm):
    email = StringField('Email', validators=[DataRequired(), Email()])
    password = PasswordField('Password', validators=[DataRequired()])
    submit = SubmitField('Login')


class RegisterForm(FlaskForm):
    name = StringField('Name', validators=[DataRequired(), Length(max=50)])
    email = StringField('Email', validators=[DataRequired(), Email()])
    password = PasswordField('Password', validators=[DataRequired(), Length(min=6)])
    confirm_password = PasswordField('Confirm Password', validators=[DataRequired(), EqualTo("password", message="Two passwords are inconsistent.")])
    role = RadioField('I want to', choices=[("Supporter", "Support campaigns"),
                                             ("Fundraiser", "Start a campaign")])
    submit = SubmitField('Register')