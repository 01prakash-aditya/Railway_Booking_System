🚆 Railway Reservation System — SQL Project
📘 Project Overview
This SQL project is a comprehensive railway reservation database system that allows users to search trains, book tickets (for up to 3 passengers), manage payments (via cards, UPI, or wallet), and handle cancellations with partial refunds. It includes:

User Authentication & Registration

Train Schedules and Stops

Coach and Seat Availability

Fare Calculation Based on Distance and Coach Type

Wallet Transactions

Stored Procedures for Bookings, Cancellations, and Queries

Triggers to manage automatic updates

🗃️ Database Schema Summary
Main Entities:
Users – Info about users including contact and type.

PaymentDetails – Card/UPI records per user.

EWallet – Balance tracking per user.

Trains – List of trains and types.

TrainSchedule – Running days & status per train.

TrainStops – Route with arrival/departure time and distance.

Coaches – Coach details like type, seats, fare.

Tickets – Booking record per journey.

Passengers – Info for each passenger in a booking.

Transactions – Payment or refund transactions.

Cancellation – Refund details on ticket cancellation.

🛠️ Setup Instructions
🧹 Step 1: Cleanup
Ensure all previous tables are dropped:

sql
Copy
Edit
DROP TABLE IF EXISTS Cancellation, Transactions, Passengers, Tickets, Coaches, TrainStops, TrainSchedule, Trains, EWallet, PaymentDetails, Users;
🏗️ Step 2: Create Tables, Triggers, and Procedures
Run the SQL script sequentially from the file to:

Create all required tables.

Add triggers for:

Validating phone numbers

Creating eWallets

Updating booking/cancellation statuses

Add stored procedures for all user and admin functionalities.

🧑‍💻 User Functions (via Stored Procedures)
✅ Registration:
sql
Copy
Edit
CALL sp_CreateUser(...); -- Registers user & sets up payment + wallet
🔐 Login:
sql
Copy
Edit
CALL sp_UserLogin(username, dob_as_password, ...);
🔎 Search Trains:
sql
Copy
Edit
CALL sp_SearchTrains('FromStation', 'ToStation', 'YYYY-MM-DD');
💳 Add Payment Method:
sql
Copy
Edit
CALL sp_AddPaymentMethod(userID, cardNumber, expiry, holderName, upi);
💰 Wallet Recharge/Deduct:
sql
Copy
Edit
CALL sp_WalletOperation(userID, amount, 'add' or 'deduct', @newBalance);
🎟️ Booking Tickets:
sql
Copy
Edit
CALL sp_BookTicket1(...); -- For 1 passenger
CALL sp_BookTicket2(...); -- For 2 passengers
CALL sp_BookTicket3(...); -- For 3 passengers
📅 View Bookings:
sql
Copy
Edit
CALL sp_ViewUserBookings(userID, 'all' | 'active' | 'cancelled', fromDate, toDate);
❌ Cancel Ticket:
sql
Copy
Edit
CALL sp_CancelTicket(ticketID, userID, 'wallet' | 'original_payment', @refund, @status);
🛠️ Admin Setup Tasks
Insert Train & Coach Data:

Populate Trains, Coaches, and TrainSchedule as per the examples.

Add Train Stops:

sql
Copy
Edit
INSERT INTO TrainStops (...) VALUES (...);
Initialize User Example:

sql
Copy
Edit
CALL sp_CreateUser(...);
UPDATE EWallet SET Balance = 2000 WHERE UserID = 1;
Call Booking/Cancel for Testing:

sql
Copy
Edit
CALL sp_BookTicket1(...);
CALL sp_CancelTicket(...);
🔁 Normalization Notes
The database design adheres to 3NF (Third Normal Form):

1NF: All attributes are atomic.

2NF: All non-key attributes depend on the full primary key.

3NF: No transitive dependencies. For example:

Users → PaymentDetails, EWallet (1-to-1/1-to-many)

TrainSchedule → Train (1-to-1)

Tickets → Users, Trains, Schedule (fully dependent)

📄 Sample Test Queries
sql
Copy
Edit
-- Check wallet balance
SELECT * FROM EWallet WHERE UserID = 1;

-- View bookings
CALL sp_ViewUserBookings(1, 'all', NULL, NULL);

-- Book ticket example
CALL sp_BookTicket1(...);

-- Cancel ticket
CALL sp_CancelTicket(2, 1, 'wallet', @amt, @status);
🧩 Future Enhancements
Support for more passengers per booking.

Admin panel to modify train schedules.

Dynamic fare based on demand.

Multi-language support.
