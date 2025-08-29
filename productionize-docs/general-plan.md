# Muvv MVP: Product Requirements Document

## 1. Overview

This document outlines the complete technical specifications, database structure, and user stories for the Minimum Viable Product (MVP) of Muvv. It serves as the single source of truth for the engineering team to build, test, and deploy the application. The primary goal of the MVP is to create a functional, reliable, and professional-feeling product that validates the core business model.

---

## Muvv MVP: Full Scope & Workflows

### 1. MVP Mission
The Muvv MVP's mission is to validate our core business model by launching a polished, reliable, and indispensable tool for the NYC dance community.  
We will solve the critical problem of class discovery and promotion by providing a centralized platform that is instantly valuable to both dancers and choreographers.  
The goal is to create a "real product" that feels complete and trustworthy from day one.

---

### 2. Core MVP Features

#### For Dancers (The Audience)
- **Frictionless Discovery:** A public, filterable browser of all upcoming classes. No account is required to browse.  
- **Powerful Filtering:** Filter classes by Style, Borough, Skill Level, and search by Choreographer or Class Title.  
- **Free Dancer Accounts:** Ability to sign up via Email/Password or Google OAuth.  

**Personalization:**
- **Class Watchlist:** Save interesting classes for later.  
- **Follow Choreographers:** Keep track of favorite instructors.  

#### For Choreographers (The Customer)
- **Exclusive Onboarding:** An invite-only system to ensure a curated, high-quality supply of instructors for launch.  
- **Digital Homebase:** A beautiful, shareable public profile (`muvv.nyc/c/your-name`) that acts as a "link-in-bio" replacement, consolidating their brand and schedule.  
- **Effortless Class Management:** A private dashboard to easily create, update, and delete class listings.  
- **Direct Booking Links:** Drive traffic directly to their preferred booking system (e.g., Mindbody, studio websites).  

#### "Magic" Features (The Stickiness Factor)
- **The "Heat" 🔥 (Social Proof):** A visual counter on each class card showing how many users have added it to their watchlist. This creates social proof and a sense of urgency (FOMO).  
- **The "Choreographer's Note" ✍️ (Human Connection):** An optional, informal field for choreographers to add a personal touch to their listings (e.g., *"This week's combo is to the new Beyoncé track!"*). This transforms a simple listing into a personal invitation.  

---

### 3. User Workflows

#### Dancer Journey
1. **Discover:** A new user lands on Muvv and immediately sees a list of upcoming classes. They notice a class with a high "Heat" count (🔥 28) and click on it.  
2. **Explore:** On the class detail page, they read the "Choreographer's Note," which gets them excited about the class. They decide they want to save it.  
3. **Engage & Convert:** They click the "Save" (❤️) icon. A modal pops up, inviting them to create a free account to save classes and follow choreographers. They quickly sign up with Google.  
4. **Retain:** Now logged in, they save the class to their watchlist and follow the choreographer. They browse the site and follow a few more of their favorite instructors, ensuring they have a reason to come back.  

#### Choreographer Journey
1. **Invitation:** A choreographer receives a personalized email with an exclusive link to join Muvv as a founding partner.  
2. **Onboarding:** They use the link to sign up on a private page. They are immediately guided to set up their "Digital Homebase" profile—adding a headshot, bio, and social links.  
3. **Create & Connect:** They navigate to their dashboard to post their first class. They fill out the details and add a "Choreographer's Note" to build hype. They publish the class.  
4. **Promote:** They copy their new Muvv profile link and update their Instagram bio, directing all their followers to one reliable source for their schedule.  

---

### 4. Key Edge Cases Handled
- **Password Resets:** A full, secure "forgot password" flow will be implemented.  
- **Class Cancellations:** Choreographers are responsible for updating or deleting their listings via their dashboard to ensure data is accurate.  
- **Account Deletion:** Will be handled manually via a support request in the MVP to keep the scope lean but will be supported.  
- **Invite System Security:** Invite tokens are single-use and expire to ensure only vetted choreographers can join.  
