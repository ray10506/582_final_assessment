from flask_wtf import FlaskForm
from wtforms import SubmitField, StringField, PasswordField, RadioField, TextAreaField, BooleanField
from wtforms.validators import DataRequired, Email, Length, EqualTo, Optional

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


class DonateForm(FlaskForm):
    # Tier choices depend on the campaign, so the view fills them in
    tier = RadioField('Choose a support tier', coerce=int,
                      validators=[DataRequired(message="Please choose a support tier.")])
    paymentMethod = RadioField('Payment method', default='Simulated card',
                               choices=[("Simulated card", "Credit card (simulated)"),
                                        ("Simulated bank transfer", "Bank transfer (simulated)")])
    message = TextAreaField('Leave a public message (optional)', validators=[Optional(), Length(max=500)])
    isAnonymous = BooleanField('Donate anonymously')
    submit = SubmitField('Donate Now')
