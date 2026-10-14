from flask import Blueprint, render_template, request, flash, redirect, url_for
from project.models import campaigns, users, campaign_subscriptions, posts, tiers_with_perks
from werkzeug.security import check_password_hash
from flask_login import login_user,logout_user, login_required
from project.forms import LoginForm, RegisterForm

bp = Blueprint('main', __name__)

@bp.route('/')
def index():
    return render_template('index.html', campaigns=campaigns.list(filters={'operational_status': 'Active', 'approval_status': 'Approved'}))

# for login page
@bp.route('/login/', methods=['GET', 'POST'])
def login():
    form = LoginForm()
    if form.validate_on_submit():
        u = users.get_by_email(form.email.data)
        if not u or not check_password_hash(u.password, form.password.data):
            flash(f"Login failed for {form.email.data}, please check your email and password.")
        elif not u.is_active:
            flash(f"Account inactive for {form.email.data}, please contact administrator.")
        else:
            login_user(u)
            flash(f"Login successful for {form.email.data}.")
            return redirect(url_for('main.index'))
    elif form.errors:
        flash(f"Form validation errors: {form.errors}")
    return render_template('login.html', form=form,
                            login_attempted=(request.method == 'POST'))

# for logout
@bp.route("/logout")
@login_required
def logout():
    logout_user()
    flash("You have been logged out.")
    return redirect(url_for('main.index'))

# for register page
@bp.route('/register/', methods=['GET', 'POST'])
def register():
    form = RegisterForm()
    if form.validate_on_submit():
        try:
            users.create({
                'name': form.name.data,
                'email': form.email.data,
                'password': form.password.data,
                'role': form.role.data
            })
            flash("Registration successful!")
            return redirect(url_for('main.login'))
        except ValueError as e:
            flash(str(e))
    elif form.errors:
        flash(f"Form validation errors: {form.errors}")
    return render_template('register.html', form=form, create_attempted=(request.method == 'POST'))

@bp.route('/donation/<int:campaign_id>')
def donation(campaign_id: int):
    campaign = campaigns.get(campaign_id)
    if campaign == None or campaign.operational_status != 'Active' or campaign.approval_status != 'Approved':
        return redirect(url_for('main.index'))
    
    fliter = {'campaignID': campaign_id }
    return render_template('donation.html',
                           campaign = campaigns.get(campaign_id),
                           subscriptions = campaign_subscriptions.list(filters = fliter | {'status': 'Active'}),
                           post = sorted(posts.list(filters = fliter), key=lambda p: p.datePosted, reverse=True),
                           tier = tiers_with_perks.list(filters = fliter)
                           )

@bp.route('/admin_dashboard/')
def admin():
    return render_template('admin_dashboard.html')

@bp.route('/campaign/')
def campaign():
    return render_template('campaign.html')