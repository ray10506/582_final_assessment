from flask import Blueprint, render_template
from project.models import categories, campaigns

bp = Blueprint('main', __name__)

@bp.route('/')
def index():
    return render_template('index.html', categories=categories.list(), campaigns=campaigns.list())

@bp.route('/donation/')
def donation():
    return render_template('donation.html')

@bp.route('/admin_dashboard/')
def admin():
    return render_template('admin_dashboard.html')

@bp.route('/campaign/')
def campaign():
    return render_template('campaign.html')