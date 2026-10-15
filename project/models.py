import json
from contextlib import contextmanager
from dataclasses import dataclass, field, fields, asdict
from datetime import date
from typing import Optional
from project import database
from werkzeug.security import generate_password_hash
from flask_login import UserMixin

#-------------------------------------------------
# DB Connection
#-------------------------------------------------
@contextmanager
def get_connection():
    conn = database.connection
    cur = conn.cursor()  ## create a cursor

    try :
        yield cur  ## yield the connection and cursor
        conn.commit()  ## commit the transaction
    except Exception as e:
        conn.rollback()  ## rollback the transaction on error
        print(f"Error: {e}")  ## print the error
        raise e  ## re-raise the exception
    finally:
        cur.close()  ## close the cursor


#-------------------------------------------------
# CRUD Class action for all tables
#-------------------------------------------------
class _CRUD:
    #constructor for the CRUD class, takes the table name, primary key, and columns as arguments
    def __init__(self, model, table_name, primary_key, columns):
        self.model = model
        self.table_name = table_name
        self.primary_key = primary_key
        self.columns = columns

    def _clean_data(self, data):
        #Remove keys from data that are not in the columns list
        return {k: v for k, v in data.items() if k in self.columns}

    #Insert a new record into the table
    def create(self, data):
        if isinstance(data, Model):
            data = asdict(data)
        data = self._clean_data(data)
        columns = ', '.join(data.keys())
        placeholders = ', '.join(['%s'] * len(data))
        with get_connection() as cur:
            cur.execute(f"INSERT INTO {self.table_name} ({columns}) VALUES ({placeholders})", tuple(data.values()))
            return cur.lastrowid

    #Retrieve a record from the table by its primary key
    def get(self, id):
        with get_connection() as cur:
            cur.execute(f"SELECT * FROM {self.table_name} WHERE {self.primary_key} = %s", (id,))
            r = cur.fetchone()
            return self.model.from_dict(r) if r else None

    #List records from the table, with optional filtering, limit, and offset
    def list(self, filters=None, limit=100, offset=0):
        filters = self._clean_data(filters or {})

        query = f"SELECT * FROM {self.table_name}"
        if filters:
            query += " WHERE " + " AND ".join([f"{k} = %s" for k in filters.keys()])
        query += f" LIMIT %s OFFSET %s"
        with get_connection() as cur:
            cur.execute(query, (*filters.values(), limit, offset))
            return [self.model.from_dict(r) for r in cur.fetchall()]

    # Update a record in the table by its primary key
    def update(self, id, data):
        data = self._clean_data(data)
        set_clause = ', '.join([f"{k} = %s" for k in data.keys()])
        with get_connection() as cur:
            cur.execute(f"UPDATE {self.table_name} SET {set_clause} WHERE {self.primary_key} = %s", (*data.values(), id))
            return cur.rowcount

    # Delete a record from the table by its primary key
    def delete(self, id):
        with get_connection() as cur:
            cur.execute(f"DELETE FROM {self.table_name} WHERE {self.primary_key} = %s", (id,))
            return cur.rowcount

# User CRUD class that extends the base _CRUD class to handle password hashing for user creation and updates
class _UserCRUD(_CRUD):
    def _create_hash_pw(self, data):
        return {**data, "password": generate_password_hash(data["password"])}

    def create(self, data):
        if self.get_by_email(data["email"]) != None:
            raise ValueError("Email already exists")
        return super().create(self._create_hash_pw(data))

    def update(self, id, data):
        if "password" in data:
            data = self._create_hash_pw(data)
        return super().update(id, data)

    def get_by_email(self, email):
        with get_connection() as cur:
            cur.execute(f"SELECT * FROM {self.table_name} WHERE email = %s", (email,))
            r = cur.fetchone()
            return self.model.from_dict(r) if r else None

class _SubscriptionCRUD(_CRUD):
    def create_subscription(self, subscriber_id: int, campaign_id: int, tier_id: int,
                            payment_method: str, message: str):

        with get_connection() as cur:
            # Lock these rows until both writes complete, so approval and price cannot change midway.
            # check the user status
            cur.execute("SELECT role, accountStatus FROM `User` WHERE id = %s FOR UPDATE", (subscriber_id,))
            user = cur.fetchone()
            if not user or user['role'] != 'Supporter' or user['accountStatus'] != 'Active':
                raise ValueError('An active Supporter account is required.')

            # check the campaign status
            cur.execute("SELECT approval_status, operational_status FROM Campaign WHERE id = %s FOR UPDATE", (campaign_id,))
            campaign = cur.fetchone()
            if not campaign or campaign['approval_status'] != 'Approved' or campaign['operational_status'] != 'Active':
                raise ValueError('This campaign is not accepting subscriptions.')

            # check the price in real time
            cur.execute("SELECT price FROM Tier WHERE id = %s AND campaignID = %s FOR UPDATE", (tier_id, campaign_id))
            tier = cur.fetchone()
            if not tier or tier['price'] <= 0:
                raise ValueError('Invalid subscription plan or price.')
            amount = tier['price']

            cur.execute(
                "INSERT INTO Subscription (subscriberID, campaignID, tierID, amount, paymentMethod, message, status, startDate) "
                "VALUES (%s, %s, %s, %s, %s, %s, 'Active', %s)",
                (subscriber_id, campaign_id, tier_id, amount, payment_method, message, date.today())
            )

            #update the current raised amount of campaign
            cur.execute(
                "UPDATE Campaign SET currentRaised = currentRaised + %s WHERE id = %s",
                (amount, campaign_id)
            )


#-------------------------------------------------
# Data Models
#-------------------------------------------------
class Model:
    # Convert a DB row (dict) into a NEW model instance
    @classmethod
    def from_dict(cls, data: dict):
        return cls(**{f.name: data[f.name] for f in fields(cls) if f.name in data})

@dataclass
class User(Model, UserMixin):
    id: int = 0
    name: str = ""
    email: str = ""
    password: str = field(default="", repr=False)  # Password should not be printed
    role: str = "User"  # Supporter | Fundraiser | Administrator
    channelName: Optional[str] = None
    bio: Optional[str] = None
    bannerImageURL: Optional[str] = None
    accountStatus: str = "Active"  # Active | Suspended

    @property
    def is_active(self):
        return self.accountStatus == "Active"


@dataclass
class Category(Model):
    id: int = 0
    name: str = ""
    description: Optional[str] = None


@dataclass
class Campaign(Model):
    id: int = 0
    title: str = ""
    description: Optional[str] = None
    imagePath: Optional[str] = None
    goalDescription: str = ""
    monthlyGoal: float = 0.0
    currentRaised: float = 0.0
    approval_status: str = "Approved"  # Pending | Approved | Rejected | Suspended
    operational_status: str = "Active"  # Active | Paused | Closed
    featured: bool = False
    categoryID: str = ""  # FK -> Category.id
    creatorID: str = ""  # FK -> User.id


@dataclass
class Tier(Model):
    id: int = 0
    campaignID: str = ""  # FK -> Campaign.id
    name: str = ""
    price: float = 0.0


@dataclass
class TierPerk(Model):
    id: int = 0
    tierID: int = 0
    campaignID: int = 0
    perk: str = ""


@dataclass
class TierWithPerks(Tier):
    perks: str = "[]"

    @property
    def perk_items(self):
        return json.loads(self.perks)


@dataclass
class Subscription(Model):
    id: int = 0
    subscriberID: str = ""  # FK -> User.id
    campaignID: str = ""  # FK -> Campaign.id
    tierID: str = ""  # FK -> Tier.id
    amount: float = 0.0
    paymentMethod: Optional[str] = None
    message: Optional[str] = None
    isAnonymous: bool = False
    status: str = "Active"  # Active | Cancelled
    startDate: Optional[date] = None
    cancelledDate: Optional[date] = None


@dataclass
class Post(Model):
    id: int = 0
    campaignID: str = ""  # FK -> Campaign.id
    title: str = ""
    description: Optional[str] = None
    visibility: str = "Public"  # Public | Subscribers
    datePosted: date = field(default_factory=date.today)


@dataclass
class PostAttachment(Model):
    # Composite PK: (postID, fileURL)
    postID: str = ""  # FK -> Post.id
    fileURL: str = ""
    fileType: str = ""


@dataclass
class Poll(Model):
    id: int = 0
    campaignID: int = 0  # FK -> Campaign.id
    question: str = ""
    status: str = "Pending"  # Pending | Active | Closed


@dataclass
class VehicleCandidate(Model):
    id: int = 0
    pollID: int = 0  # FK -> Poll.id
    vehicleName: str = ""
    imageURL: Optional[str] = None


@dataclass
class Vote(Model):
    # Composite PK: (pollID, subscriberID) - one vote per subscriber per poll
    pollID: int = 0  # FK -> Poll.id
    subscriberID: int = 0  # FK -> User.id
    candidateID: int = 0  # FK -> VehicleCandidate.id (must belong to pollID)
    dateVoted: date = field(default_factory=date.today)


@dataclass
class Comment(Model):
    id: int = 0
    campaignID: int = 0  # FK -> Campaign.id
    subscriberID: int = 0  # FK -> User.id
    text: str = ""
    datePosted: date = field(default_factory=date.today)


@dataclass
class Report(Model):
    id: int = 0
    contentType: str = ""  # Comment | Post | User | Campaign
    contentID: int = 0  # id of the reported row; table depends on contentType
    reason: str = ""
    reportCount: int = 1
    status: str = "Pending"  # Pending | Dismissed | Actioned

@dataclass
class CampaignSubscriptions(Model):
    subscriptionID: int
    campaignID: int
    campaignTitle: str
    goalDescription: str
    creatorID: int
    subscriberID: int
    subscriberName: str
    tierID: int
    tierName: str
    tierPrice: float
    tierPerks: Optional[str]
    amount: float
    paymentMethod: Optional[str]
    message: Optional[str]
    isAnonymous: bool
    status: str
    startDate: Optional[date]
    cancelledDate: Optional[date]


#-------------------------------------------------
# Create CRUD instances for each table
#-------------------------------------------------
users = _UserCRUD(User, "User", "id", ["id", "name", "email", "password", "role", "channelName", "bio", "bannerImageURL", "accountStatus"])
categories = _CRUD(Category, "Category", "id", ["id", "name", "description"])
campaigns = _CRUD(Campaign, "Campaign", "id", ["id", "title", "description", "goalDescription", "monthlyGoal", "currentRaised", "approval_status", "operational_status", "featured", "categoryID", "creatorID", "imagePath"])
tiers = _CRUD(Tier, "Tier", "id", ["id", "campaignID", "name", "price"])
tier_perks = _CRUD(TierPerk, "TierPerks", "id", ["id", "tierID", "campaignID", "perk"])
tiers_with_perks = _CRUD(TierWithPerks, "TierWithPerks", "id", ["id", "campaignID", "name", "price", "perks"])
subscriptions = _SubscriptionCRUD(Subscription, "Subscription", "id", ["id", "subscriberID", "campaignID", "tierID", "amount", "paymentMethod", "message", "isAnonymous", "status", "startDate", "cancelledDate"])
posts = _CRUD(Post, "Post", "id", ["id", "campaignID", "title", "description", "visibility", "datePosted"]) 
post_attachments = _CRUD(PostAttachment, "PostAttachment", "postID", ["postID", "fileURL", "fileType"])
polls = _CRUD(Poll, "Poll", "id", ["id", "campaignID", "question", "status"])
vehicle_candidates = _CRUD(VehicleCandidate, "VehicleCandidate", "id", ["id", "pollID", "vehicleName", "imageURL"])
votes = _CRUD(Vote, "Vote", "pollID", ["pollID", "subscriberID", "candidateID", "dateVoted"])
comments = _CRUD(Comment, "Comment", "id", ["id", "campaignID", "subscriberID", "text", "datePosted"])
reports = _CRUD(Report, "Report", "id", ["id", "contentType", "contentID", "reason", "reportCount", "status"])
campaign_subscriptions = _CRUD(CampaignSubscriptions, "CampaignSubscriptions", "subscriptionID", ["campaignID", "status"])