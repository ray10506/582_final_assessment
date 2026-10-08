from dataclasses import dataclass, field
from datetime import date
from typing import Optional
from uuid import uuid4

# Field names match the database.sql column names exactly, so a DictCursor row
# maps straight onto a model: Campaign(**row).
# Foreign keys are stored as the referenced row's id (str).


def new_id() -> str:
    return str(uuid4())

@dataclass
class User:
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
class Category:
    id: str = field(default_factory=new_id)
    name: str = ""
    description: Optional[str] = None


@dataclass
class Campaign:
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
class Tier:
    id: str = field(default_factory=new_id)
    campaignID: str = ""  # FK -> Campaign.id
    name: str = ""
    price: float = 0.0
    perks: Optional[str] = None


@dataclass
class Subscription:
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
class Post:
    id: str = field(default_factory=new_id)
    campaignID: str = ""  # FK -> Campaign.id
    title: str = ""
    description: Optional[str] = None
    visibility: str = "Public"  # Public | Subscribers
    datePosted: date = field(default_factory=date.today)


@dataclass
class PostAttachment:
    # Composite PK: (postID, fileURL)
    postID: str = ""  # FK -> Post.id
    fileURL: str = ""
    fileType: str = ""


@dataclass
class Poll:
    id: str = field(default_factory=new_id)
    campaignID: str = ""  # FK -> Campaign.id
    question: str = ""
    status: str = "Pending"  # Pending | Active | Closed


@dataclass
class VehicleCandidate:
    id: str = field(default_factory=new_id)
    pollID: str = ""  # FK -> Poll.id
    vehicleName: str = ""
    imageURL: Optional[str] = None


@dataclass
class Vote:
    # Composite PK: (pollID, subscriberID) - one vote per subscriber per poll
    pollID: str = ""  # FK -> Poll.id
    subscriberID: str = ""  # FK -> User.id
    candidateID: str = ""  # FK -> VehicleCandidate.id (must belong to pollID)
    dateVoted: date = field(default_factory=date.today)


@dataclass
class Comment:
    id: str = field(default_factory=new_id)
    campaignID: str = ""  # FK -> Campaign.id
    subscriberID: str = ""  # FK -> User.id
    text: str = ""
    datePosted: date = field(default_factory=date.today)


@dataclass
class Report:
    id: str = field(default_factory=new_id)
    contentType: str = ""  # Comment | Post | User | Campaign
    contentID: str = ""  # id of the reported row; table depends on contentType
    reason: str = ""
    reportCount: int = 1
    status: str = "Pending"  # Pending | Dismissed | Actioned
