from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import date
from typing import Optional
from uuid import uuid4
from dataclasses import dataclass, fields
# from warnings import filters
from project import database
from dataclasses import asdict


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
            return self.model.from_dict(self.model, r) if r else None

    #List records from the table, with optional filtering, limit, and offset
    def list(self, filters=None, limit=100, offset=0):
        filters = self._clean_data(filters or {})

        query = f"SELECT * FROM {self.table_name}"
        if filters:
            query += " WHERE " + " AND ".join([f"{k} = %s" for k in filters.keys()])
        query += f" LIMIT %s OFFSET %s"
        with get_connection() as cur:
            cur.execute(query, (*filters.values(), limit, offset))
            return [self.model.from_dict(self.model, r) for r in cur.fetchall()]

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





#-------------------------------------------------
# Data Models
#-------------------------------------------------
def new_id() -> str:
    return str(uuid4())
    
class Model:
    # Convert dict to model instance
    def from_dict(self, data: dict):
        for f in fields(self):
            if f.name in data:
                setattr(self, f.name, data[f.name])
        return self

@dataclass
class User(Model):
    id: str = field(default_factory=new_id)
    name: str = ""
    email: str = ""
    password: str = field(default="", repr=False)  # Password should not be printed
    role: str = "User"  # User | Supporter | Fundraiser | Administrator
    channelName: Optional[str] = None
    bio: Optional[str] = None
    bannerImageURL: Optional[str] = None
    accountStatus: str = "Active"  # Active | Suspended


@dataclass
class Category(Model):
    id: str = field(default_factory=new_id)
    name: str = ""
    description: Optional[str] = None


@dataclass
class Campaign(Model):
    id: str = field(default_factory=new_id)
    title: str = ""
    description: Optional[str] = None
    monthlyGoal: float = 0.0
    currentRaised: float = 0.0
    status: str = "Pending"  # Pending | Active | ...
    featured: bool = False
    categoryID: str = ""  # FK -> Category.id
    creatorID: str = ""  # FK -> User.id


@dataclass
class Tier(Model):
    id: str = field(default_factory=new_id)
    campaignID: str = ""  # FK -> Campaign.id
    name: str = ""
    price: float = 0.0
    perks: Optional[str] = None


@dataclass
class Subscription(Model):
    id: str = field(default_factory=new_id)
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
    id: str = field(default_factory=new_id)
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
    id: str = field(default_factory=new_id)
    campaignID: str = ""  # FK -> Campaign.id
    question: str = ""
    status: str = "Pending"  # Pending | Active | Closed


@dataclass
class VehicleCandidate(Model):
    id: str = field(default_factory=new_id)
    pollID: str = ""  # FK -> Poll.id
    vehicleName: str = ""
    imageURL: Optional[str] = None


@dataclass
class Vote(Model):
    # Composite PK: (pollID, subscriberID) - one vote per subscriber per poll
    pollID: str = ""  # FK -> Poll.id
    subscriberID: str = ""  # FK -> User.id
    candidateID: str = ""  # FK -> VehicleCandidate.id (must belong to pollID)
    dateVoted: date = field(default_factory=date.today)


@dataclass
class Comment(Model):
    id: str = field(default_factory=new_id)
    campaignID: str = ""  # FK -> Campaign.id
    subscriberID: str = ""  # FK -> User.id
    text: str = ""
    datePosted: date = field(default_factory=date.today)


@dataclass
class Report(Model):
    id: str = field(default_factory=new_id)
    contentType: str = ""  # Comment | Post | User | Campaign
    contentID: str = ""  # id of the reported row; table depends on contentType
    reason: str = ""
    reportCount: int = 1
    status: str = "Pending"  # Pending | Dismissed | Actioned



#-------------------------------------------------
# Create CRUD instances for each table
#-------------------------------------------------
users = _CRUD(User, "User", "id", ["id", "name", "email", "password", "role", "channelName", "bio", "bannerImageURL", "accountStatus"])
categories = _CRUD(Category, "Category", "id", ["id", "name", "description"])
campaigns = _CRUD(Campaign, "Campaign", "id", ["id", "title", "description", "monthlyGoal", "currentRaised", "status", "featured", "categoryID", "creatorID"])
tiers = _CRUD(Tier, "Tier", "id", ["id", "campaignID", "name", "price", "perks"])
subscriptions = _CRUD(Subscription, "Subscription", "id", ["id", "subscriberID", "campaignID", "tierID", "amount", "paymentMethod", "message", "isAnonymous", "status", "startDate", "cancelledDate"])
posts = _CRUD(Post, "Post", "id", ["id", "campaignID", "title", "description", "visibility", "datePosted"]) 
post_attachments = _CRUD(PostAttachment, "PostAttachment", "postID", ["postID", "fileURL", "fileType"])
polls = _CRUD(Poll, "Poll", "id", ["id", "campaignID", "question", "status"])
vehicle_candidates = _CRUD(VehicleCandidate, "VehicleCandidate", "id", ["id", "pollID", "vehicleName", "imageURL"])
votes = _CRUD(Vote, "Vote", "pollID", ["pollID", "subscriberID", "candidateID", "dateVoted"])
comments = _CRUD(Comment, "Comment", "id", ["id", "campaignID", "subscriberID", "text", "datePosted"])
reports = _CRUD(Report, "Report", "id", ["id", "contentType", "contentID", "reason", "reportCount", "status"])