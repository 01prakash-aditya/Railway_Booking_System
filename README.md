🚆 Railway Reservation System – Mini Project
This mini-project implements a comprehensive Railway Reservation System using SQL. It manages operations like ticket booking, seat allocation, refunds, passenger records, train schedules, and more through robust table design, procedures, and triggers.

📂 Database Schema
The project uses the following key entities:

🔹 Main Tables
Passenger – Stores passenger details including age, contact, and concessions.

Station – Records stations with names and locations.

Train – Holds train details, source, and destination stations.

Route – Defines train stopovers with arrival/departure and stop number.

Schedule – Tracks each train's daily run/cancellation.

Class – Class types (Sleeper, AC, etc.) and fare per kilometer.

Seat – Maps train-class combinations with seat numbers.

Ticket – Booking status, seat assignment, and PNR for each passenger.

Payment – Tracks payment mode, amount, refund status, and ticket linkage.

🔹 Relationship Tables (RL)
TicketPassenger – Links tickets to multiple passengers.

SeatAvailability – Tracks if a seat is booked on a given schedule.

TrainClass – Maps classes available on each train.

RAC_WL_Status – Stores waitlist/RAC positions and statuses.

⚙️ Stored Procedures
Includes logic for:

GetPNRStatus – Fetch ticket status by PNR.

GetTrainSchedule – Show train run schedule.

GetAvailableSeats – List unbooked seats for given class/date.

GetPassengersByTrainDate – List passengers on a train/date.

GetWaitlistedPassengers – Show WL passengers for a train.

GetTotalRefundForCancelledTrain – Calculate refund for canceled trains.

GetRevenue – Calculate total earnings for a date range.

GetCancellationRecords – Show refund status for canceled trains.

GetBusiestRoute – Determine most traveled station in routes.

GetItemizedBill – Generate ticket-wise bill with class-wise fare.

🔁 Triggers
Automation via:

AfterTicketInsert – Marks seat booked on confirmation.

AfterTrainCancellation – Auto-updates refunds if a train is canceled.

BeforePaymentInsert – Validates positive payment amounts.

PreventDoubleBooking – Prevents double seat booking.

(Note: A placeholder trigger for RAC/WL reallocation on cancellations is provided.)

🧠 Features
PNR status check

RAC/WL queue integration

Train-wise passenger tracking

Automatic seat allocation and refunding

Revenue and busiest route analytics

Fully normalized table design

📌 Notes
All procedures and triggers use MySQL's syntax with appropriate delimiters.

Enum constraints enforce consistency (e.g., Gender, ConcessionCategory).

Proper foreign keys maintain referential integrity across the system.

Additional logic (e.g., RAC/WL seat reallocation) can be implemented on top.
