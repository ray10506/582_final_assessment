import os
from datetime import date
from flask import Blueprint, render_template, request, flash, redirect, url_for, abort, current_app
from project.models import campaigns, categories, users, tiers, subscriptions, posts, post_attachments, comments
from werkzeug.security import check_password_hash
from flask_login import login_user,logout_user, login_required, current_user
from project.forms import LoginForm, RegisterForm, DonateForm

bp = Blueprint('main', __name__)

@bp.route('/')
def index():
    q = request.args.get('q', '').strip()
    category_id = request.args.get('category', type=int)

    visible = campaigns.list(filters={'operational_status': 'Active', 'approval_status': 'Approved'})
    featured = [c for c in visible if c.featured]

    # filters only supports "column = value", so search and category filtering happen in Python
    results = visible
    if category_id:
        results = [c for c in results if c.categoryID == category_id]
    if q:
        needle = q.lower()
        results = [c for c in results
                   if needle in c.title.lower() or needle in (c.description or '').lower()]

    return render_template('index.html',
                           campaigns=results,
                           featured=featured,
                           categories=categories.list(),
                           q=q,
                           category_id=category_id)

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
            print(str(e))
            flash(str(e))
    elif form.errors:
        print(f"Form validation errors: {form.errors}")
        flash(f"Form validation errors: {form.errors}")
    return render_template('register.html', form=form, create_attempted=(request.method == 'POST'))

# for campaign detail + donation page
def _get_visible_campaign(id):
    # Unapproved campaigns are only visible to their creator and admins
    campaign = campaigns.get(id)
    if campaign is None:
        abort(404)
    if campaign.approval_status != 'Approved':
        is_owner = current_user.is_authenticated and current_user.id == campaign.creatorID
        is_admin = current_user.is_authenticated and current_user.role == 'Administrator'
        if not (is_owner or is_admin):
            abort(404)
    return campaign


def _render_campaign(campaign, form):
    campaign_tiers = sorted(tiers.list(filters={'campaignID': campaign.id}), key=lambda t: t.price)
    form.tier.choices = [(t.id, f"{t.name} - ${t.price:,.2f}/mo") for t in campaign_tiers]
    tier_names = {t.id: t.name for t in campaign_tiers}

    active_subs = subscriptions.list(filters={'campaignID': campaign.id, 'status': 'Active'})
    donor_names = {u_id: users.get(u_id).name for u_id in {s.subscriberID for s in active_subs}}
    donations = [{'name': 'Anonymous' if s.isAnonymous else donor_names[s.subscriberID],
                  'amount': s.amount,
                  'tier': tier_names.get(s.tierID, ''),
                  'message': s.message,
                  'date': s.startDate}
                 for s in sorted(active_subs, key=lambda s: s.startDate or date.min, reverse=True)]

    # Subscriber-only posts are readable by the campaign's supporters, its creator and admins
    can_view_private = current_user.is_authenticated and (
        current_user.id == campaign.creatorID
        or current_user.role == 'Administrator'
        or any(s.subscriberID == current_user.id for s in active_subs))
    campaign_posts = []
    for p in sorted(posts.list(filters={'campaignID': campaign.id}), key=lambda p: p.datePosted, reverse=True):
        images, files = [], []
        for a in post_attachments.list(filters={'postID': p.id}):
            filename = os.path.basename(a.fileURL)
            # Only show an image if the file is actually in static/img; otherwise list it by name
            if a.fileType.startswith('image/') and os.path.exists(os.path.join(current_app.static_folder, 'img', filename)):
                images.append(filename)
            else:
                files.append(filename)
        campaign_posts.append({'post': p, 'images': images, 'files': files,
                               'locked': p.visibility == 'Subscribers' and not can_view_private})

    campaign_comments = sorted(comments.list(filters={'campaignID': campaign.id}), key=lambda c: c.datePosted, reverse=True)
    commenter_names = {u_id: users.get(u_id).name for u_id in {c.subscriberID for c in campaign_comments}}

    return render_template('donation.html',
                           campaign=campaign,
                           creator=users.get(campaign.creatorID),
                           category=categories.get(campaign.categoryID),
                           tiers=campaign_tiers,
                           donations=donations,
                           posts=campaign_posts,
                           comments=campaign_comments,
                           commenter_names=commenter_names,
                           raised=campaign.currentRaised,
                           form=form)


@bp.route('/donation/<int:id>/')
def donation(id):
    return _render_campaign(_get_visible_campaign(id), DonateForm())


@bp.route('/donation/<int:id>/donate', methods=['POST'])
@login_required
def donate(id):
    campaign = _get_visible_campaign(id)
    if current_user.role != 'Supporter':
        flash("Only supporter accounts can donate.", "danger")
        return redirect(url_for('main.donation', id=id))
    if campaign.approval_status != 'Approved' or campaign.operational_status != 'Active':
        flash("This campaign is not accepting donations right now.", "danger")
        return redirect(url_for('main.donation', id=id))

    form = DonateForm()
    # Choices must be set before validation so the chosen tier is checked against this campaign's tiers
    campaign_tiers = {t.id: t for t in tiers.list(filters={'campaignID': campaign.id})}
    form.tier.choices = [(t_id, t.name) for t_id, t in campaign_tiers.items()]
    if form.validate_on_submit():
        tier = campaign_tiers[form.tier.data]
        subscriptions.create({
            'subscriberID': current_user.id,
            'campaignID': campaign.id,
            'tierID': tier.id,
            'amount': tier.price,
            'paymentMethod': form.paymentMethod.data,
            'message': form.message.data or None,
            'isAnonymous': form.isAnonymous.data,
            'status': 'Active',
            'startDate': date.today(),
        })
        campaigns.update(campaign.id, {'currentRaised': campaign.currentRaised + tier.price})
        flash(f"Thank you! You are now supporting {campaign.title} at the {tier.name} tier.", "success")
        return redirect(url_for('main.donation', id=id))

    flash("Your donation was not completed. Please check the form below.", "danger")
    return _render_campaign(campaign, form)

@bp.route('/admin_dashboard/')
def admin():
    return render_template('admin_dashboard.html')

@bp.route('/campaign/')
def campaign():
    return render_template('campaign.html')