from MySQLdb import Error as DatabaseError
from flask import Blueprint, render_template, request, flash, redirect, url_for, abort, current_app
from project.models import campaigns, users, campaign_subscriptions, posts, tiers_with_perks, subscriptions, tiers
from werkzeug.security import check_password_hash
from flask_login import login_user,logout_user, login_required, current_user
from project.forms import LoginForm, RegisterForm, SubscriptionForm

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

# for donation pages
@bp.route('/donation/<int:campaign_id>', methods=['GET', 'POST'])
def donation(campaign_id: int):
    campaign = campaigns.get(campaign_id)
    if campaign == None or campaign.operational_status != 'Active' or campaign.approval_status != 'Approved':
        return redirect(url_for('main.index'))

    form = SubscriptionForm()
    filters = {'campaignID': campaign_id}
    tier = tiers_with_perks.list(filters=filters)

    form.tierID.choices = [(t.id, t.name) for t in tier]
    if request.method == 'GET' and tier:
        form.tierID.data = tier[0].id

    if form.validate_on_submit():
        if not current_user.is_authenticated:
            flash('Please log in as a Supporter to subscribe.')
            return redirect(url_for('main.login'))

        try:
            subscriptions.create_subscription(
                subscriber_id=current_user.id,
                campaign_id=campaign_id,
                tier_id=form.tierID.data,
                payment_method=form.paymentMethod.data,
                message=form.message.data,
            )
            flash("Subscription successful!")
        except ValueError as error:
            flash(str(error), 'danger')
        except DatabaseError:
            current_app.logger.exception('Subscription could not be saved')
            flash('Unable to save your subscription. Please try again.', 'danger')
        # Redirect after a successful POST so a refresh can't resubmit and double-count the pledge.
        return redirect(url_for('main.donation', campaign_id=campaign_id))
    return render_template('donation.html',
                           form=form,
                           campaign=campaign,
                           subscriptions=campaign_subscriptions.list(filters=filters | {'status': 'Active'}),
                           post=sorted(posts.list(filters=filters), key=lambda p: p.datePosted, reverse=True),
                           tier=tier)


@bp.route('/admin_dashboard/')
def admin():
    return render_template('admin_dashboard.html')

@bp.route('/campaign/')
def campaign():
    return render_template('campaign.html')