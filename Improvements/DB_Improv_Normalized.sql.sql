CREATE TABLE User (
    UserID INT PRIMARY KEY AUTO_INCREMENT,
    Username VARCHAR(50) UNIQUE NOT NULL,
    Password VARCHAR(255) NOT NULL, -- Should store hashed passwords
    Email VARCHAR(100) UNIQUE NOT NULL,
    PhoneNumber VARCHAR(15),
    IsVerified BOOLEAN DEFAULT FALSE,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    LastLoginAt DATETIME,
    Role ENUM('Customer', 'Agent', 'Admin') DEFAULT 'Customer'
);
CREATE TABLE Station (
    StationID INT PRIMARY KEY AUTO_INCREMENT,
    StationName VARCHAR(100) NOT NULL,
    Location VARCHAR(100)
);
CREATE TABLE Train (
    TrainID INT PRIMARY KEY AUTO_INCREMENT,
    TrainName VARCHAR(100) NOT NULL,
    TrainType ENUM('Express', 'Superfast', 'Mail', 'Local') NOT NULL,
    SourceStationID INT,
    DestinationStationID INT,
    FOREIGN KEY (SourceStationID) REFERENCES Station(StationID),
    FOREIGN KEY (DestinationStationID) REFERENCES Station(StationID)
);
CREATE TABLE Schedule (
    ScheduleID INT PRIMARY KEY AUTO_INCREMENT,
    TrainID INT,
    Date DATE,
    Status ENUM('Running', 'Cancelled') DEFAULT 'Running',
    Remarks VARCHAR(255), -- Added for status updates/notes
    FOREIGN KEY (TrainID) REFERENCES Train(TrainID)
);
CREATE TABLE Route (
    RouteID INT PRIMARY KEY AUTO_INCREMENT,
    TrainID INT,
    StationID INT,
    ArrivalTime TIME,
    DepartureTime TIME,
    StopNumber INT,
    Distance DECIMAL(10,2) DEFAULT 0, -- Added Distance for fare calculation
    FOREIGN KEY (TrainID) REFERENCES Train(TrainID),
    FOREIGN KEY (StationID) REFERENCES Station(StationID)
);
CREATE TABLE Class (
    ClassID INT PRIMARY KEY AUTO_INCREMENT,
    ClassName ENUM('Sleeper', 'AC 3-Tier', 'AC 2-Tier', 'First Class') NOT NULL,
    FarePerKM DECIMAL(6,2) NOT NULL
);
CREATE TABLE TrainClass (
    TrainID INT,
    ClassID INT,
    PRIMARY KEY (TrainID, ClassID),
    FOREIGN KEY (TrainID) REFERENCES Train(TrainID),
    FOREIGN KEY (ClassID) REFERENCES Class(ClassID)
);
CREATE TABLE Seat (
    SeatID INT PRIMARY KEY AUTO_INCREMENT,
    TrainID INT,
    ClassID INT,
    SeatNumber VARCHAR(10) NOT NULL,
    SeatType ENUM('Window', 'Middle', 'Aisle', 'Lower Berth', 'Middle Berth', 'Upper Berth', 'Side Lower', 'Side Upper') NOT NULL, -- Added seat type
    FOREIGN KEY (TrainID) REFERENCES Train(TrainID),
    FOREIGN KEY (ClassID) REFERENCES Class(ClassID)
);
CREATE TABLE SeatAvailability (
    ScheduleID INT,
    SeatID INT,
    IsBooked BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (ScheduleID, SeatID),
    FOREIGN KEY (ScheduleID) REFERENCES Schedule(ScheduleID),
    FOREIGN KEY (SeatID) REFERENCES Seat(SeatID)
);
CREATE TABLE Passenger (
    PassengerID INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL,
    Age INT CHECK (Age > 0),
    Gender ENUM('Male', 'Female', 'Other') NOT NULL,
    ContactNumber VARCHAR(15) NOT NULL,
    Email VARCHAR(100),
    ConcessionCategory ENUM('Senior Citizen', 'Student', 'Disabled', 'None') DEFAULT 'None',
    UserID INT,
    FOREIGN KEY (UserID) REFERENCES User(UserID)
);
CREATE TABLE Ticket (
    TicketID INT PRIMARY KEY AUTO_INCREMENT,
    PassengerID INT,
    ScheduleID INT,
    ClassID INT,
    BookingStatus ENUM('Confirmed', 'RAC', 'WL') NOT NULL,
    SeatID INT, -- Can be NULL for WL/RAC
    PNR VARCHAR(20) UNIQUE NOT NULL,
    BookingDate DATE NOT NULL,
    JourneyDistance DECIMAL(10,2) DEFAULT 0, -- Added for fare calculation
    BookingSourceType ENUM('Mobile App', 'Website', 'Counter', 'Agent') NOT NULL DEFAULT 'Website', -- Added booking source
    FOREIGN KEY (PassengerID) REFERENCES Passenger(PassengerID),
    FOREIGN KEY (ScheduleID) REFERENCES Schedule(ScheduleID),
    FOREIGN KEY (ClassID) REFERENCES Class(ClassID),
    FOREIGN KEY (SeatID) REFERENCES Seat(SeatID)
);
CREATE TABLE TicketPassenger (
    TicketID INT,
    PassengerID INT,
    PRIMARY KEY (TicketID, PassengerID),
    FOREIGN KEY (TicketID) REFERENCES Ticket(TicketID),
    FOREIGN KEY (PassengerID) REFERENCES Passenger(PassengerID)
);
CREATE TABLE RAC_WL_Status (
    TicketID INT PRIMARY KEY,
    QueueNumber INT NOT NULL,
    CurrentStatus ENUM('RAC', 'WL') NOT NULL,
    FOREIGN KEY (TicketID) REFERENCES Ticket(TicketID)
);
CREATE TABLE RouteFare (
    RouteFareID INT PRIMARY KEY AUTO_INCREMENT,
    TrainID INT NOT NULL,
    ClassID INT NOT NULL,
    SourceStationID INT NOT NULL,
    DestinationStationID INT NOT NULL,
    FixedFare DECIMAL(10,2) NOT NULL, -- Fixed, not dynamic
    FOREIGN KEY (TrainID) REFERENCES Train(TrainID),
    FOREIGN KEY (ClassID) REFERENCES Class(ClassID),
    FOREIGN KEY (SourceStationID) REFERENCES Station(StationID),
    FOREIGN KEY (DestinationStationID) REFERENCES Station(StationID)
);
CREATE TABLE Payment (
    PaymentID INT PRIMARY KEY AUTO_INCREMENT,
    TicketID INT UNIQUE,
    PaymentMode ENUM('Online', 'Counter') NOT NULL,
    Amount DECIMAL(10,2) NOT NULL,
    PaymentDate DATE NOT NULL,
    RefundStatus ENUM('Yes', 'No') DEFAULT 'No',
    FOREIGN KEY (TicketID) REFERENCES Ticket(TicketID)
);
CREATE TABLE Notification (
    NotificationID INT PRIMARY KEY AUTO_INCREMENT,
    UserID INT,
    TicketID INT,
    NotificationType ENUM('Booking', 'Cancellation', 'Delay', 'Platform Change', 'General') NOT NULL,
    Message TEXT NOT NULL,
    SentAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    IsRead BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (UserID) REFERENCES User(UserID),
    FOREIGN KEY (TicketID) REFERENCES Ticket(TicketID)
);
CREATE TABLE TicketCancellation (
    CancellationID INT PRIMARY KEY AUTO_INCREMENT,
    TicketID INT NOT NULL,
    CancellationDate DATETIME NOT NULL,
    CancellationReason VARCHAR(255),
    CancellationCharge DECIMAL(10,2) DEFAULT 0, -- Based on fixed rules, not dynamic
    FOREIGN KEY (TicketID) REFERENCES Ticket(TicketID)
);


DELIMITER //
CREATE PROCEDURE CheckBookingAvailability(
    IN p_train_id INT,
    IN p_journey_date DATE,
    IN p_class_id INT
)
BEGIN
    DECLARE v_schedule_id INT;
    DECLARE v_available_seats INT;
    DECLARE v_total_seats INT;
    DECLARE v_rac_capacity INT;
    DECLARE v_current_rac INT;
    DECLARE v_current_wl INT;

    SELECT ScheduleID INTO v_schedule_id 
    FROM Schedule 
    WHERE TrainID = p_train_id AND Date = p_journey_date
    LIMIT 1;

    SELECT COUNT(*) INTO v_available_seats
    FROM SeatAvailability sa
    JOIN Seat s ON sa.SeatID = s.SeatID
    WHERE sa.ScheduleID = v_schedule_id
      AND s.ClassID = p_class_id
      AND sa.IsBooked = FALSE;

    IF v_available_seats > 0 THEN
        SELECT 'Available' AS Status, v_available_seats AS AvailableSeats, NULL AS QueueNumber;
    ELSE
        SELECT COUNT(*) INTO v_total_seats FROM Seat WHERE ClassID = p_class_id;
        SET v_rac_capacity = FLOOR(v_total_seats * 0.5);

        SELECT COUNT(*) INTO v_current_rac
        FROM RAC_WL_Status rws
        JOIN Ticket t ON rws.TicketID = t.TicketID
        WHERE t.ScheduleID = v_schedule_id
          AND t.ClassID = p_class_id
          AND rws.CurrentStatus = 'RAC';

        IF v_current_rac < v_rac_capacity THEN
            SELECT 'RAC' AS Status, NULL AS AvailableSeats, v_current_rac + 1 AS QueueNumber;
        ELSE
            SELECT COUNT(*) INTO v_current_wl
            FROM RAC_WL_Status rws
            JOIN Ticket t ON rws.TicketID = t.TicketID
            WHERE t.ScheduleID = v_schedule_id
              AND t.ClassID = p_class_id
              AND rws.CurrentStatus = 'WL';

            SELECT 'Waitlist' AS Status, NULL AS AvailableSeats, v_current_wl + 1 AS QueueNumber;
        END IF;
    END IF;
END //
DELIMITER ;
DELIMITER //

CREATE PROCEDURE FindAvailableTrains(
    IN from_station_name VARCHAR(100),
    IN to_station_name VARCHAR(100),
    IN journey_date DATE
)
BEGIN
    DECLARE from_station_id INT;
    DECLARE to_station_id INT;

    -- Get station IDs from names
    SELECT StationID INTO from_station_id 
    FROM Station 
    WHERE StationName = from_station_name LIMIT 1;

    SELECT StationID INTO to_station_id 
    FROM Station 
    WHERE StationName = to_station_name LIMIT 1;

    -- Main query
    SELECT 
        t.TrainID,
        t.TrainName,
        t.TrainType,
        src.StationName AS SourceStation,
        dest.StationName AS DestinationStation,
        sch.Date AS JourneyDate,
        r1.StopNumber AS FromStopNumber,
        r2.StopNumber AS ToStopNumber,
        TIMEDIFF(r2.ArrivalTime, r1.DepartureTime) AS JourneyDuration
    FROM Route r1
    JOIN Route r2 ON r1.TrainID = r2.TrainID
    JOIN Train t ON r1.TrainID = t.TrainID
    JOIN Schedule sch ON t.TrainID = sch.TrainID
    JOIN Station src ON t.SourceStationID = src.StationID
    JOIN Station dest ON t.DestinationStationID = dest.StationID
    WHERE r1.StationID = from_station_id
    AND r2.StationID = to_station_id
    AND r1.StopNumber < r2.StopNumber
    AND sch.Date = journey_date
    ORDER BY JourneyDuration ASC;
END //

DELIMITER ;

DELIMITER //
CREATE PROCEDURE CalculateTicketFare(
    IN train_id INT,
    IN class_id INT,
    IN source_station_id INT,
    IN destination_station_id INT,
    IN passenger_id INT,
    OUT total_fare DECIMAL(10,2)
)
BEGIN
    DECLARE base_fare DECIMAL(10,2);
    DECLARE concession_percentage DECIMAL(5,2) DEFAULT 0;
    
    -- Get fixed fare for the route
    SELECT FixedFare INTO base_fare
    FROM RouteFare
    WHERE TrainID = train_id 
    AND ClassID = class_id
    AND SourceStationID = source_station_id
    AND DestinationStationID = destination_station_id;
    
    -- Get concession percentage based on passenger category
    SELECT 
        CASE 
            WHEN ConcessionCategory = 'Senior Citizen' THEN 40
            WHEN ConcessionCategory = 'Student' THEN 25
            WHEN ConcessionCategory = 'Disabled' THEN 50
            ELSE 0
        END INTO concession_percentage
    FROM Passenger
    WHERE PassengerID = passenger_id;
    
    -- Apply concession
    SET total_fare = base_fare - (base_fare * concession_percentage / 100);
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE BookMultipleTickets(
    IN train_id INT,
    IN journey_date DATE,
    IN class_id INT,
    IN passenger_details JSON,
    IN payment_mode ENUM('Online', 'Counter'),
    IN user_id INT
)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE max_passengers INT DEFAULT 4;
    DECLARE pnr VARCHAR(20);
    DECLARE ticket_count INT DEFAULT 0;
    DECLARE available_seats INT;
    DECLARE current_seat_id INT;
    DECLARE total_amount DECIMAL(10,2) DEFAULT 0;
    DECLARE schedule_id INT;
    
    START TRANSACTION;
    
    -- Generate PNR
    SET pnr = CONCAT(UPPER(SUBSTRING(MD5(RAND()) FROM 1 FOR 6)), CAST(UNIX_TIMESTAMP() AS CHAR));
    
    -- Get schedule ID
    SELECT ScheduleID INTO schedule_id FROM Schedule 
    WHERE TrainID = train_id AND Date = journey_date LIMIT 1;
    
    -- Create temporary passengers table
    CREATE TEMPORARY TABLE TempPassengers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100),
        age INT,
        gender ENUM('Male', 'Female', 'Other'),
        contact VARCHAR(15),
        email VARCHAR(100),
        concession ENUM('Senior Citizen', 'Student', 'Disabled', 'None')
    );
    
    INSERT INTO TempPassengers (name, age, gender, contact, email, concession)
    SELECT 
        js->>"$.name", 
        js->>"$.age", 
        js->>"$.gender", 
        js->>"$.contact", 
        js->>"$.email", 
        js->>"$.concession"
    FROM JSON_TABLE(passenger_details, '$[*]' COLUMNS (js JSON PATH '$')) AS jt;
    
    -- Main booking loop
    WHILE i < JSON_LENGTH(passenger_details) AND i < max_passengers DO
        SET i = i + 1;
        
        -- Insert passenger
        INSERT INTO Passenger (Name, Age, Gender, ContactNumber, Email, ConcessionCategory, UserID)
        SELECT name, age, gender, contact, email, concession, user_id
        FROM TempPassengers WHERE id = i;
        
        SET @passenger_id = LAST_INSERT_ID();
        
        -- Calculate fare
        CALL CalculateTicketFare(
            train_id,
            class_id,
            (SELECT SourceStationID FROM Train WHERE TrainID = train_id),
            (SELECT DestinationStationID FROM Train WHERE TrainID = train_id),
            @passenger_id,
            @ticket_fare
        );
        
        SET total_amount = total_amount + @ticket_fare;
        
        -- Check availability
        CALL CheckBookingAvailability(train_id, journey_date, class_id);
        
        -- Insert ticket
        INSERT INTO Ticket (
            PassengerID, ScheduleID, ClassID, 
            BookingStatus, SeatID, PNR, BookingDate, BookingSourceType
        ) VALUES (
            @passenger_id, schedule_id, class_id,
            CASE
                WHEN (SELECT Status FROM CheckBookingAvailability) = 'Available' THEN 'Confirmed'
                WHEN (SELECT Status FROM CheckBookingAvailability) = 'RAC' THEN 'RAC'
                ELSE 'WL'
            END,
            CASE 
                WHEN (SELECT Status FROM CheckBookingAvailability) = 'Available' THEN (
                    SELECT sa.SeatID FROM SeatAvailability sa
                    JOIN Seat s ON sa.SeatID = s.SeatID
                    WHERE sa.ScheduleID = schedule_id 
                    AND s.ClassID = class_id 
                    AND sa.IsBooked = FALSE
                    LIMIT 1
                )
                ELSE NULL
            END,
            pnr, CURDATE(), 'Website'
        );
        
        SET @ticket_id = LAST_INSERT_ID();
        
        -- Update seat/RAC/WL status
        IF (SELECT Status FROM CheckBookingAvailability) = 'Confirmed' THEN
            UPDATE SeatAvailability SET IsBooked = TRUE 
            WHERE SeatID = (SELECT SeatID FROM Ticket WHERE TicketID = @ticket_id);
        ELSE
            INSERT INTO RAC_WL_Status (TicketID, QueueNumber, CurrentStatus)
            VALUES (
                @ticket_id,
                (SELECT QueueNumber FROM CheckBookingAvailability),
                (SELECT Status FROM CheckBookingAvailability)
            );
        END IF;
        
        -- Link ticket to passenger
        INSERT INTO TicketPassenger (TicketID, PassengerID) 
        VALUES (@ticket_id, @passenger_id);
        
        SET ticket_count = ticket_count + 1;
    END WHILE;
    
    -- Create payment record
    INSERT INTO Payment (TicketID, PaymentMode, Amount, PaymentDate)
    VALUES (@ticket_id, payment_mode, total_amount, CURDATE());
    
    COMMIT;
    
    -- Return booking summary
    SELECT 
        pnr AS PNRNumber,
        ticket_count AS TotalTickets,
        (SELECT COUNT(*) FROM Ticket WHERE PNR = pnr AND BookingStatus = 'Confirmed') AS Confirmed,
        (SELECT COUNT(*) FROM Ticket WHERE PNR = pnr AND BookingStatus = 'RAC') AS RAC,
        (SELECT COUNT(*) FROM Ticket WHERE PNR = pnr AND BookingStatus = 'WL') AS Waitlist,
        total_amount AS TotalAmount;
    
    DROP TEMPORARY TABLE TempPassengers;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE GetPNRStatus(IN pnr VARCHAR(20))
BEGIN
    SELECT t.PNR, t.BookingStatus, t.SeatID, s.SeatNumber, s.SeatType, c.ClassName,
           tr.TrainName, sch.Date
    FROM Ticket t
    JOIN Schedule sch ON t.ScheduleID = sch.ScheduleID
    JOIN Train tr ON sch.TrainID = tr.TrainID
    LEFT JOIN Seat s ON t.SeatID = s.SeatID
    JOIN Class c ON t.ClassID = c.ClassID
    WHERE t.PNR = pnr;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE GetTrainSchedule(IN train_id INT)
BEGIN
    SELECT s.ScheduleID, s.Date, s.Status, s.Remarks
    FROM Schedule s
    WHERE s.TrainID = train_id;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE GetAvailableSeats(
    IN train_id INT,
    IN journey_date DATE,
    IN class_id INT)
BEGIN
    SELECT sa.SeatID, s.SeatNumber, s.SeatType
    FROM SeatAvailability sa
    JOIN Seat s ON sa.SeatID = s.SeatID
    JOIN Schedule sch ON sa.ScheduleID = sch.ScheduleID
    WHERE sch.TrainID = train_id 
    AND sch.Date = journey_date
    AND s.ClassID = class_id 
    AND sa.IsBooked = FALSE;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE GetPassengersByTrainDate(
    IN train_id INT,
    IN journey_date DATE)
BEGIN
    SELECT DISTINCT p.PassengerID, p.Name, p.Age, p.Gender, p.ConcessionCategory,
           t.PNR, t.BookingStatus, s.SeatNumber
    FROM Passenger p
    JOIN Ticket t ON p.PassengerID = t.PassengerID
    JOIN Schedule sch ON t.ScheduleID = sch.ScheduleID
    LEFT JOIN Seat s ON t.SeatID = s.SeatID
    WHERE sch.TrainID = train_id AND sch.Date = journey_date;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE GetWaitlistedPassengers(IN train_id INT)
BEGIN
    SELECT p.PassengerID, p.Name, t.PNR, sch.Date,
           rws.QueueNumber, rws.CurrentStatus
    FROM Passenger p
    JOIN Ticket t ON p.PassengerID = t.PassengerID
    JOIN Schedule sch ON t.ScheduleID = sch.ScheduleID
    JOIN RAC_WL_Status rws ON t.TicketID = rws.TicketID
    WHERE sch.TrainID = train_id AND t.BookingStatus = 'WL';
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE GetRevenue(IN start_date DATE, IN end_date DATE)
BEGIN
    SELECT SUM(Amount) AS TotalRevenue
    FROM Payment
    WHERE PaymentDate BETWEEN start_date AND end_date AND RefundStatus = 'No';
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE GetTotalRefundForCancelledTrain(IN train_id INT)
BEGIN
    SELECT SUM(pay.Amount) AS TotalRefund
    FROM Payment pay
    JOIN Ticket t ON pay.TicketID = t.TicketID
    JOIN Schedule s ON t.ScheduleID = s.ScheduleID
    WHERE s.TrainID = train_id AND s.Status = 'Cancelled' AND pay.RefundStatus = 'Yes';
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE CalculateCancellationCharge(
    IN ticket_id INT,
    OUT cancellation_charge DECIMAL(10,2)
)
BEGIN
    DECLARE ticket_amount DECIMAL(10,2);
    DECLARE journey_date DATE;
    DECLARE cancellation_date DATE;
    DECLARE days_before_journey INT;
    
    -- Get ticket amount
    SELECT Amount INTO ticket_amount
    FROM Payment
    WHERE TicketID = ticket_id;
    
    -- Get journey date
    SELECT s.Date INTO journey_date
    FROM Ticket t
    JOIN Schedule s ON t.ScheduleID = s.ScheduleID
    WHERE t.TicketID = ticket_id;
    
    -- Get current date
    SET cancellation_date = CURRENT_DATE();
    
    -- Calculate days before journey
    SET days_before_journey = DATEDIFF(journey_date, cancellation_date);
    
    -- Calculate cancellation charge based on fixed rules
    IF days_before_journey > 15 THEN
        SET cancellation_charge = ticket_amount * 0.10; -- 10% charge
    ELSEIF days_before_journey > 7 THEN
        SET cancellation_charge = ticket_amount * 0.25; -- 25% charge
    ELSEIF days_before_journey > 1 THEN
        SET cancellation_charge = ticket_amount * 0.50; -- 50% charge
    ELSE
        SET cancellation_charge = ticket_amount * 0.75; -- 75% charge if cancelled on the day or day before
    END IF;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE ProcessWaitlistAfterCancellation(IN schedule_id INT, IN class_id INT)
BEGIN
    DECLARE next_wl_ticket_id INT;
    DECLARE next_rac_ticket_id INT;
    DECLARE available_seat_id INT;
    
    -- Get the next WL ticket to be upgraded to RAC
    SELECT t.TicketID INTO next_wl_ticket_id
    FROM Ticket t
    JOIN RAC_WL_Status rws ON t.TicketID = rws.TicketID
    WHERE t.ScheduleID = schedule_id
    AND t.ClassID = class_id
    AND t.BookingStatus = 'WL'
    AND rws.CurrentStatus = 'WL'
    ORDER BY rws.QueueNumber
    LIMIT 1;
    
    -- Get the next RAC ticket to be confirmed
    SELECT t.TicketID INTO next_rac_ticket_id
    FROM Ticket t
    JOIN RAC_WL_Status rws ON t.TicketID = rws.TicketID
    WHERE t.ScheduleID = schedule_id
    AND t.ClassID = class_id
    AND t.BookingStatus = 'RAC'
    AND rws.CurrentStatus = 'RAC'
    ORDER BY rws.QueueNumber
    LIMIT 1;
    
    -- Find available seat
    SELECT sa.SeatID INTO available_seat_id
    FROM SeatAvailability sa
    JOIN Seat s ON sa.SeatID = s.SeatID
    WHERE sa.ScheduleID = schedule_id
    AND sa.IsBooked = FALSE
    AND s.ClassID = class_id
    LIMIT 1;
    
    -- Update RAC ticket to Confirmed if available
    IF next_rac_ticket_id IS NOT NULL AND available_seat_id IS NOT NULL THEN
        UPDATE Ticket
        SET BookingStatus = 'Confirmed', SeatID = available_seat_id
        WHERE TicketID = next_rac_ticket_id;
        
        UPDATE SeatAvailability
        SET IsBooked = TRUE
        WHERE ScheduleID = schedule_id AND SeatID = available_seat_id;
        
        DELETE FROM RAC_WL_Status
        WHERE TicketID = next_rac_ticket_id;
        
        -- Move WL to RAC
        IF next_wl_ticket_id IS NOT NULL THEN
            UPDATE Ticket
            SET BookingStatus = 'RAC'
            WHERE TicketID = next_wl_ticket_id;
            
            UPDATE RAC_WL_Status
            SET CurrentStatus = 'RAC'
            WHERE TicketID = next_wl_ticket_id;
        END IF;
    END IF;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE GetCancellationRecords()
BEGIN
    SELECT t.TicketID, t.PNR, s.Status AS TrainStatus, pay.RefundStatus,
           tc.CancellationDate, tc.CancellationReason, tc.CancellationCharge
    FROM Ticket t
    JOIN Schedule s ON t.ScheduleID = s.ScheduleID
    JOIN Payment pay ON t.TicketID = pay.TicketID
    LEFT JOIN TicketCancellation tc ON t.TicketID = tc.TicketID
    WHERE s.Status = 'Cancelled' OR tc.CancellationID IS NOT NULL;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE GetBusiestRoute()
BEGIN
    SELECT r.StationID, st.StationName, COUNT(t.TicketID) AS PassengerCount
    FROM Route r
    JOIN Station st ON r.StationID = st.StationID
    JOIN Schedule s ON r.TrainID = s.TrainID
    JOIN Ticket t ON s.ScheduleID = t.ScheduleID
    GROUP BY r.StationID, st.StationName
    ORDER BY PassengerCount DESC
    LIMIT 1;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE GetItemizedBill(IN ticket_id INT)
BEGIN
    SELECT t.TicketID, t.PNR, c.ClassName, 
           t.JourneyDistance, c.FarePerKM, 
           (t.JourneyDistance * c.FarePerKM) AS BaseAmount,
           p.Amount AS TotalAmount,
           pay.PaymentMode, pay.PaymentDate
    FROM Ticket t
    JOIN Class c ON t.ClassID = c.ClassID
    JOIN Payment p ON t.TicketID = p.TicketID
    JOIN Payment pay ON p.TicketID = pay.TicketID
    WHERE t.TicketID = ticket_id;
END //
DELIMITER ;



CREATE VIEW TicketDetailView AS
SELECT 
    t.TicketID, 
    t.PNR, 
    p.Name AS PassengerName,
    p.Age,
    p.Gender,
    p.ConcessionCategory,
    c.ClassName,
    tr.TrainName,
    tr.TrainType,
    s_source.StationName AS SourceStation,
    s_dest.StationName AS DestinationStation,
    sch.Date AS JourneyDate,
    t.BookingStatus,
    CASE 
        WHEN t.BookingStatus = 'WL' THEN 
            CONCAT('WL-', (SELECT QueueNumber FROM RAC_WL_Status WHERE TicketID = t.TicketID))
        WHEN t.BookingStatus = 'RAC' THEN
            CONCAT('RAC-', (SELECT QueueNumber FROM RAC_WL_Status WHERE TicketID = t.TicketID))
        ELSE 
            CONCAT(st.SeatType, '-', s.SeatNumber)
    END AS SeatInfo,
    pay.Amount,
    pay.PaymentMode,
    t.BookingDate
FROM 
    Ticket t
JOIN Passenger p ON t.PassengerID = p.PassengerID
JOIN Class c ON t.ClassID = c.ClassID
JOIN Schedule sch ON t.ScheduleID = sch.ScheduleID
JOIN Train tr ON sch.TrainID = tr.TrainID
JOIN Station s_source ON tr.SourceStationID = s_source.StationID
JOIN Station s_dest ON tr.DestinationStationID = s_dest.StationID
LEFT JOIN Seat s ON t.SeatID = s.SeatID
LEFT JOIN Payment pay ON t.TicketID = pay.TicketID
LEFT JOIN Seat st ON s.SeatID = st.SeatID;


DELIMITER //
CREATE TRIGGER AfterTicketInsert
AFTER INSERT ON Ticket
FOR EACH ROW
BEGIN
    IF NEW.BookingStatus = 'Confirmed' THEN
        UPDATE SeatAvailability
        SET IsBooked = TRUE
        WHERE SeatID = NEW.SeatID AND ScheduleID = NEW.ScheduleID;
    END IF;
END//
DELIMITER ;


DELIMITER //
CREATE TRIGGER UpdateWaitlistQueue
AFTER INSERT ON Ticket
FOR EACH ROW
BEGIN
    DECLARE current_max_queue INT;
    
    IF NEW.BookingStatus = 'WL' THEN
        -- Find the current maximum queue number for this schedule and class
        SELECT COALESCE(MAX(QueueNumber), 0) INTO current_max_queue
        FROM RAC_WL_Status rws
        JOIN Ticket t ON rws.TicketID = t.TicketID
        WHERE t.ScheduleID = NEW.ScheduleID 
        AND t.ClassID = NEW.ClassID
        AND rws.CurrentStatus = 'WL';
        
        -- Insert new record with incremented queue number
        INSERT INTO RAC_WL_Status (TicketID, QueueNumber, CurrentStatus)
        VALUES (NEW.TicketID, current_max_queue + 1, 'WL');
    END IF;
    
    IF NEW.BookingStatus = 'RAC' THEN
        -- Find the current maximum queue number for this schedule and class
        SELECT COALESCE(MAX(QueueNumber), 0) INTO current_max_queue
        FROM RAC_WL_Status rws
        JOIN Ticket t ON rws.TicketID = t.TicketID
        WHERE t.ScheduleID = NEW.ScheduleID 
        AND t.ClassID = NEW.ClassID
        AND rws.CurrentStatus = 'RAC';
        
        -- Insert new record with incremented queue number
        INSERT INTO RAC_WL_Status (TicketID, QueueNumber, CurrentStatus)
        VALUES (NEW.TicketID, current_max_queue + 1, 'RAC');
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER AfterTrainCancellation
AFTER UPDATE ON Schedule
FOR EACH ROW
BEGIN
    IF NEW.Status = 'Cancelled' AND OLD.Status != 'Cancelled' THEN
        UPDATE Payment p
        JOIN Ticket t ON p.TicketID = t.TicketID
        SET p.RefundStatus = 'Yes'
        WHERE t.ScheduleID = NEW.ScheduleID;
    END IF;
END//
DELIMITER ;


DELIMITER //
CREATE TRIGGER PreventDoubleBooking
BEFORE INSERT ON Ticket
FOR EACH ROW
BEGIN
    IF NEW.BookingStatus = 'Confirmed' AND EXISTS (
        SELECT 1 FROM Ticket
        WHERE SeatID = NEW.SeatID AND ScheduleID = NEW.ScheduleID AND BookingStatus = 'Confirmed'
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Seat already booked';
    END IF;
END//
DELIMITER ;


DELIMITER //
CREATE TRIGGER AfterTicketCancellation
AFTER INSERT ON TicketCancellation
FOR EACH ROW
BEGIN
    DECLARE schedule_id INT;
    DECLARE class_id INT;
    
    -- Get schedule_id and class_id of the cancelled ticket
    SELECT ScheduleID, ClassID INTO schedule_id, class_id
    FROM Ticket
    WHERE TicketID = NEW.TicketID;
    
    -- Call procedure to process waitlist
    CALL ProcessWaitlistAfterCancellation(schedule_id, class_id);
END//
DELIMITER ;

