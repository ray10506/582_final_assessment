from flask import Blueprint, render_template 

bp = Blueprint('main', __name__)

@bp.route('/')
def index():
    return render_template('index.html')

@bp.route('/donation/')
def donation():
    return render_template('donation.html')

@bp.route('/admin_dashboard/')
def admin():
    return render_template('admin_dashboard.html')

@bp.route('/campaign/')
def campaign():
    return render_template('campaign.html')