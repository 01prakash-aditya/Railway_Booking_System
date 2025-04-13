-- Drop tables if they exist (order matters due to foreign key constraints)
DROP TABLE IF EXISTS Cancellation;
DROP TABLE IF EXISTS Transactions;
DROP TABLE IF EXISTS Passengers;
DROP TABLE IF EXISTS Tickets;
DROP TABLE IF EXISTS Coaches;
DROP TABLE IF EXISTS TrainStops;
DROP TABLE IF EXISTS TrainSchedule;
DROP TABLE IF EXISTS Trains;
DROP TABLE IF EXISTS EWallet;
DROP TABLE IF EXISTS PaymentDetails;
DROP TABLE IF EXISTS Users;

-- -----------------------------------------------------------
-- 1. USERS and RELATED TABLES
-- -----------------------------------------------------------

CREATE TABLE Users (
    UserID INT AUTO_INCREMENT PRIMARY KEY,
    Username VARCHAR(50) NOT NULL UNIQUE,
    DOB DATE NOT NULL,
    Email VARCHAR(100) NOT NULL UNIQUE,
    PhonePrimary VARCHAR(20),
    PhoneSecondary VARCHAR(20),
    UserType VARCHAR(20) DEFAULT 'normal'
) ENGINE=InnoDB;

-- PaymentDetails (each user can register both card and UPI)
CREATE TABLE PaymentDetails (
    PaymentID INT AUTO_INCREMENT PRIMARY KEY,
    UserID INT NOT NULL,
    CardNumber VARCHAR(20) DEFAULT NULL,
    CardExpiry VARCHAR(7) DEFAULT NULL,
    CardHolderName VARCHAR(100) DEFAULT NULL,
    UPI_ID VARCHAR(50) DEFAULT NULL,
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedOn TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE
) ENGINE=InnoDB;

-- EWallet table (one wallet per user)
CREATE TABLE EWallet (
    WalletID INT AUTO_INCREMENT PRIMARY KEY,
    UserID INT NOT NULL UNIQUE,
    Balance DECIMAL(10,2) DEFAULT 0.00,
    LastUpdated TIMESTAMP DEFAULT NOW() ON UPDATE NOW(),
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------------
-- 2. TRAIN, SCHEDULE, COACHES, TICKETING, AND TRANSACTIONS
-- -----------------------------------------------------------

-- Trains: basic info about each train
CREATE TABLE Trains (
    TrainID INT AUTO_INCREMENT PRIMARY KEY,
    TrainNumber VARCHAR(20) NOT NULL UNIQUE,
    TrainName VARCHAR(100) NOT NULL,
    TrainType VARCHAR(20) NOT NULL,  -- passenger, local, luxury, etc.
    CreatedOn TIMESTAMP DEFAULT NOW()
) ENGINE=InnoDB;

-- TrainSchedule: journey info for each train
CREATE TABLE TrainSchedule (
    ScheduleID INT AUTO_INCREMENT PRIMARY KEY,
    TrainID INT NOT NULL,
    RunningDays VARCHAR(50) NOT NULL, -- e.g., 'Mon,Wed,Fri'
    Status VARCHAR(20) DEFAULT 'active',  -- active/suspended
    LastUpdated TIMESTAMP DEFAULT NOW() ON UPDATE NOW(),
    FOREIGN KEY (TrainID) REFERENCES Trains(TrainID) ON DELETE CASCADE
) ENGINE=InnoDB;

-- TrainStops: multiple stops for each train schedule
CREATE TABLE TrainStops (
    StopID INT AUTO_INCREMENT PRIMARY KEY,
    ScheduleID INT NOT NULL,
    StationName VARCHAR(50) NOT NULL,
    StopNumber INT NOT NULL,  -- Sequential order of stops
    ArrivalTime TIME,         -- NULL for first station
    DepartureTime TIME,       -- NULL for last station
    Distance INT DEFAULT 0,   -- Distance from origin in km
    FOREIGN KEY (ScheduleID) REFERENCES TrainSchedule(ScheduleID) ON DELETE CASCADE,
    UNIQUE KEY (ScheduleID, StopNumber)
) ENGINE=InnoDB;

-- Coaches: defines the coaches available for a given train
CREATE TABLE Coaches (
    CoachID INT AUTO_INCREMENT PRIMARY KEY,
    TrainID INT NOT NULL,
    CoachType VARCHAR(10) NOT NULL,  -- e.g., 3A, 2A, 1A, SL, GN, CC, EC
    CoachNumber VARCHAR(10) NOT NULL, -- e.g., B1, B2, A1, etc.
    TotalSeats INT NOT NULL,
    AvailableSeats INT NOT NULL,
    BaseFare DECIMAL(10,2) NOT NULL,  -- Base fare per seat
    FOREIGN KEY (TrainID) REFERENCES Trains(TrainID) ON DELETE CASCADE,
    UNIQUE KEY (TrainID, CoachNumber)
) ENGINE=InnoDB;

-- Tickets: one record per booking (a booking may include multiple passengers)
CREATE TABLE Tickets (
    TicketID INT AUTO_INCREMENT PRIMARY KEY,
    PNR VARCHAR(20) NOT NULL UNIQUE,
    UserID INT NOT NULL,
    TrainID INT NOT NULL,
    ScheduleID INT NOT NULL,
    FromStation VARCHAR(50) NOT NULL,
    ToStation VARCHAR(50) NOT NULL,
    BookingDate TIMESTAMP DEFAULT NOW(),
    JourneyDate DATE NOT NULL,
    TotalPassengers INT NOT NULL,
    TotalFare DECIMAL(10,2) NOT NULL,
    PaymentMethod VARCHAR(20) NOT NULL,  -- card, upi, wallet
    PaymentID INT DEFAULT NULL,          -- NULL if wallet is used
    BookingStatus VARCHAR(20) DEFAULT 'confirmed',  -- confirmed, cancelled
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (TrainID) REFERENCES Trains(TrainID) ON DELETE CASCADE,
    FOREIGN KEY (ScheduleID) REFERENCES TrainSchedule(ScheduleID) ON DELETE CASCADE,
    FOREIGN KEY (PaymentID) REFERENCES PaymentDetails(PaymentID) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Passengers: details for each person on a ticket
CREATE TABLE Passengers (
    PassengerID INT AUTO_INCREMENT PRIMARY KEY,
    TicketID INT NOT NULL,
    Name VARCHAR(50) NOT NULL,
    Age INT NOT NULL,
    Gender CHAR(1) NOT NULL,
    CoachType VARCHAR(10) NOT NULL,
    SeatAllocation VARCHAR(20) DEFAULT NULL,  -- e.g., seat number or RAC/WL position
    BookingStatus VARCHAR(20) DEFAULT 'confirmed',  -- confirmed, cancelled, RAC, WL
    FOREIGN KEY (TicketID) REFERENCES Tickets(TicketID) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Transactions: record for each successful or failed payment / refund
CREATE TABLE Transactions (
    TransactionID INT AUTO_INCREMENT PRIMARY KEY,
    TicketID INT NOT NULL,
    UserID INT NOT NULL,
    Amount DECIMAL(10,2) NOT NULL,
    TransactionType VARCHAR(20) NOT NULL,  -- booking, cancellation
    TransactionDate TIMESTAMP DEFAULT NOW(),
    PaymentMethod VARCHAR(20) NOT NULL,  -- card, upi, wallet
    PaymentStatus VARCHAR(20) NOT NULL,  -- confirmed, failed, refunded
    Remarks VARCHAR(255) DEFAULT NULL,
    FOREIGN KEY (TicketID) REFERENCES Tickets(TicketID) ON DELETE CASCADE,
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Cancellation: record cancellation and refund details
CREATE TABLE Cancellation (
    CancellationID INT AUTO_INCREMENT PRIMARY KEY,
    TicketID INT NOT NULL,
    CancellationDate TIMESTAMP DEFAULT NOW(),
    RefundAmount DECIMAL(10,2) NOT NULL,
    RefundStatus VARCHAR(20) DEFAULT 'processed',
    RefundTo VARCHAR(20) NOT NULL,  -- wallet, original_payment
    FOREIGN KEY (TicketID) REFERENCES Tickets(TicketID) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Seats (
    SeatID INT AUTO_INCREMENT PRIMARY KEY,
    CoachID INT NOT NULL,
    SeatNumber VARCHAR(10) NOT NULL,
    IsAvailable BOOLEAN DEFAULT TRUE,
    JourneyDate DATE NOT NULL,
    ScheduleID INT NOT NULL,

    FOREIGN KEY (CoachID) REFERENCES Coaches(CoachID),
    FOREIGN KEY (ScheduleID) REFERENCES TrainSchedule(ScheduleID),
    UNIQUE (CoachID, SeatNumber, JourneyDate)
);

-------------------------------------------------------------
-- 3. TRIGGERS
-------------------------------------------------------------

-- (a) Trigger to validate that at least one phone number is provided in Users
DELIMITER $$
CREATE TRIGGER trg_validate_phone
BEFORE INSERT ON Users
FOR EACH ROW
BEGIN
    IF (NEW.PhonePrimary IS NULL AND NEW.PhoneSecondary IS NULL) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'At least one phone number must be provided.';
    END IF;
END$$
DELIMITER ;

-- Also add for UPDATE
DELIMITER $$
CREATE TRIGGER trg_validate_phone_update
BEFORE UPDATE ON Users
FOR EACH ROW
BEGIN
    IF (NEW.PhonePrimary IS NULL AND NEW.PhoneSecondary IS NULL) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'At least one phone number must be provided.';
    END IF;
END$$
DELIMITER ;

-- (b) Trigger to automatically create an EWallet record after a new User is added
DELIMITER $$
CREATE TRIGGER trg_create_ewallet
AFTER INSERT ON Users
FOR EACH ROW
BEGIN
    INSERT INTO EWallet(UserID, Balance) VALUES (NEW.UserID, 0.00);
END$$
DELIMITER ;

-- (c) Trigger to update passenger status when a ticket is cancelled
DELIMITER $$
CREATE TRIGGER trg_update_passenger_status
AFTER UPDATE ON Tickets
FOR EACH ROW
BEGIN
    IF NEW.BookingStatus = 'cancelled' AND OLD.BookingStatus <> 'cancelled' THEN
        -- Update all passengers for this ticket to cancelled status
        UPDATE Passengers
        SET BookingStatus = 'cancelled'
        WHERE TicketID = NEW.TicketID;
    END IF;
END$$
DELIMITER ;

-- (d) Trigger to update EWallet balance when a refund is processed
DELIMITER $$
CREATE TRIGGER trg_process_refund
AFTER INSERT ON Cancellation
FOR EACH ROW
BEGIN
    DECLARE v_UserID INT;
    
    -- Get the UserID associated with the ticket
    SELECT UserID INTO v_UserID
    FROM Tickets
    WHERE TicketID = NEW.TicketID;
    
    -- If refund goes to wallet, update wallet balance
    IF NEW.RefundTo = 'wallet' THEN
        UPDATE EWallet
        SET Balance = Balance + NEW.RefundAmount,
            LastUpdated = NOW()
        WHERE UserID = v_UserID;
    END IF;
END$$
DELIMITER ;

-- (e) Trigger to update wallet balance when paying with wallet
DELIMITER $$
CREATE TRIGGER trg_wallet_payment
AFTER INSERT ON Tickets
FOR EACH ROW
BEGIN
    IF NEW.PaymentMethod = 'wallet' THEN
        -- Deduct the fare amount from wallet
        UPDATE EWallet
        SET Balance = Balance - NEW.TotalFare,
            LastUpdated = NOW()
        WHERE UserID = NEW.UserID;
    END IF;
END$$
DELIMITER ;

-- -----------------------------------------------------------
-- 4. STORED PROCEDURES
-- -----------------------------------------------------------


-- (a) User Registration Procedure
DELIMITER $$
CREATE PROCEDURE sp_CreateUser(
    IN p_Username VARCHAR(50),
    IN p_DOB DATE,
    IN p_Email VARCHAR(100),
    IN p_PhonePrimary VARCHAR(20),
    IN p_PhoneSecondary VARCHAR(20),
    IN p_CardNumber VARCHAR(20),
    IN p_CardExpiry VARCHAR(7),
    IN p_CardHolderName VARCHAR(100),
    IN p_UPI_ID VARCHAR(50),
    IN p_UserType VARCHAR(20),
    OUT p_UserID INT
)
BEGIN
    -- Start transaction for atomic operation
    START TRANSACTION;
    
    -- Insert new user
    INSERT INTO Users (
        Username, DOB, Email, PhonePrimary, PhoneSecondary, UserType
    )
    VALUES (
        p_Username, p_DOB, p_Email, p_PhonePrimary, p_PhoneSecondary, 
        IFNULL(p_UserType, 'normal')
    );
    
    -- Get user ID
    SET p_UserID = LAST_INSERT_ID();
    
    -- Insert payment details if provided
    IF p_CardNumber IS NOT NULL OR p_UPI_ID IS NOT NULL THEN
        INSERT INTO PaymentDetails (
            UserID, CardNumber, CardExpiry, CardHolderName, UPI_ID
        )
        VALUES (
            p_UserID, p_CardNumber, p_CardExpiry, p_CardHolderName, p_UPI_ID
        );
    END IF;
    
    -- EWallet is created automatically by trigger
    
    COMMIT;
    
    -- Return the new user's ID
    SELECT p_UserID AS NewUserID;
END$$
DELIMITER ;

drop procedure sp_UserLogin;

-- (b) User Authentication Procedure
DELIMITER $$
CREATE PROCEDURE sp_UserLogin(
    IN p_Username VARCHAR(50),
    IN p_Password VARCHAR(50),
    OUT p_IsAuthenticated BOOLEAN,
    OUT p_UserID INT,
    OUT p_UserType VARCHAR(20)
)
BEGIN
    DECLARE v_Count INT DEFAULT 0;
    
    -- Check if username and DOB (as password) match
    SELECT COUNT(*), UserID, UserType INTO v_Count, p_UserID, p_UserType
    FROM Users
    WHERE Username = p_Username
      AND DATE_FORMAT(DOB, '%d%m%Y') = p_Password
    LIMIT 1;
    
    -- Set authentication result
    IF v_Count > 0 THEN
        SET p_IsAuthenticated = TRUE;
    ELSE
        SET p_IsAuthenticated = FALSE;
        SET p_UserID = NULL;
        SET p_UserType = NULL;
    END IF;
END$$
DELIMITER ;

drop procedure sp_SearchTrains;

-- (c) Procedure to search for trains between stations on a specific date
DELIMITER $$
CREATE PROCEDURE sp_SearchTrains(
    IN p_FromStation VARCHAR(50),
    IN p_ToStation VARCHAR(50),
    IN p_JourneyDate DATE
)
BEGIN
    DECLARE v_Day VARCHAR(10);
    SET v_Day = DAYNAME(p_JourneyDate);
    
    -- Get first 3 letters of day
    SET v_Day = LEFT(v_Day, 3);
    
    SELECT 
        t.TrainID, 
        t.TrainNumber, 
        t.TrainName, 
        t.TrainType,
        ts.ScheduleID,
        origin.StationName AS FromStation,
        origin.DepartureTime AS DepartureTime,
        dest.StationName AS ToStation,
        dest.ArrivalTime AS ArrivalTime,
        dest.Distance - origin.Distance AS JourneyDistance,
        ts.RunningDays,
        c.CoachType,
        c.CoachNumber,
        c.AvailableSeats,
        c.BaseFare,
        ROUND(c.BaseFare * (dest.Distance - origin.Distance) / 100, 2) AS CalculatedFare
    FROM 
        Trains t
    JOIN 
        TrainSchedule ts ON t.TrainID = ts.TrainID
    JOIN 
        TrainStops origin ON ts.ScheduleID = origin.ScheduleID
    JOIN 
        TrainStops dest ON ts.ScheduleID = dest.ScheduleID
    JOIN 
        Coaches c ON t.TrainID = c.TrainID
    WHERE 
        origin.StationName = p_FromStation
        AND dest.StationName = p_ToStation
        AND origin.StopNumber < dest.StopNumber
        AND ts.Status = 'active'
        AND ts.RunningDays LIKE CONCAT('%', v_Day, '%')
        AND c.AvailableSeats > 0
    ORDER BY 
        origin.DepartureTime;
END$$
DELIMITER ;

-- (d) Add payment method procedure
DELIMITER $$
CREATE PROCEDURE sp_AddPaymentMethod(
    IN p_UserID INT,
    IN p_CardNumber VARCHAR(20),
    IN p_CardExpiry VARCHAR(7),
    IN p_CardHolderName VARCHAR(100),
    IN p_UPI_ID VARCHAR(50)
)
BEGIN
    INSERT INTO PaymentDetails (
        UserID, CardNumber, CardExpiry, CardHolderName, UPI_ID
    )
    VALUES (
        p_UserID, p_CardNumber, p_CardExpiry, p_CardHolderName, p_UPI_ID
    );
    
    SELECT LAST_INSERT_ID() AS NewPaymentID;
END$$
DELIMITER ;

-- (e) Wallet operations procedure
DELIMITER $$
CREATE PROCEDURE sp_WalletOperation(
    IN p_UserID INT,
    IN p_Amount DECIMAL(10,2),
    IN p_Operation VARCHAR(10),  -- 'add' or 'deduct'
    OUT p_NewBalance DECIMAL(10,2)
)
BEGIN
    DECLARE v_Balance DECIMAL(10,2);
    
    -- Get current balance
    SELECT Balance INTO v_Balance
    FROM EWallet
    WHERE UserID = p_UserID;
    
    IF p_Operation = 'add' THEN
        -- Add funds to wallet
        UPDATE EWallet
        SET Balance = Balance + p_Amount,
            LastUpdated = NOW()
        WHERE UserID = p_UserID;
    ELSEIF p_Operation = 'deduct' THEN
        -- Check if sufficient balance
        IF v_Balance < p_Amount THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Insufficient wallet balance';
        END IF;
        
        -- Deduct funds from wallet
        UPDATE EWallet
        SET Balance = Balance - p_Amount,
            LastUpdated = NOW()
        WHERE UserID = p_UserID;
    END IF;
    
    -- Get updated balance
    SELECT Balance INTO p_NewBalance
    FROM EWallet
    WHERE UserID = p_UserID;
END$$
DELIMITER ;

call sp_WalletOperation(1,1000,'add',@new);

drop procedure sp_BookTicket1;

DELIMITER $$

CREATE PROCEDURE sp_BookTicket1(
    IN p_UserID INT,
    IN p_TrainID INT,
    IN p_ScheduleID INT,
    IN p_FromStation VARCHAR(50),
    IN p_ToStation VARCHAR(50),
    IN p_JourneyDate DATE,
    IN p_CoachType VARCHAR(10),
    IN p_PassengerName VARCHAR(50),
    IN p_PassengerAge INT,
    IN p_PassengerGender CHAR(1),
    IN p_PaymentMethod VARCHAR(20),
    IN p_PaymentID INT,
    OUT p_PNR VARCHAR(20),
    OUT p_TicketID INT
)
BEGIN
    DECLARE v_TotalSeats INT;
    DECLARE v_ConfirmedLimit INT;
    DECLARE v_RACLimit INT;
    DECLARE v_BookedConfirmed INT;
    DECLARE v_BookedRAC INT;
    DECLARE v_WLCount INT;
    DECLARE v_Fare DECIMAL(10,2);
    DECLARE v_WalletBalance DECIMAL(10,2);
    DECLARE v_FromDistance INT;
    DECLARE v_ToDistance INT;
    DECLARE v_Distance INT;
    DECLARE v_BookingStatus VARCHAR(20);
    DECLARE v_SeatAllocation VARCHAR(50);
    DECLARE v_RACSeatNo INT;

    START TRANSACTION;

    -- Get total seats in the coach
    SELECT TotalSeats INTO v_TotalSeats
    FROM Coaches
    WHERE TrainID = p_TrainID AND CoachType = p_CoachType
    LIMIT 1;

    SET v_ConfirmedLimit = FLOOR(v_TotalSeats * 0.8);
    SET v_RACLimit = (v_TotalSeats - v_ConfirmedLimit) * 2;

    -- Count confirmed bookings
    SELECT COUNT(*) INTO v_BookedConfirmed
    FROM Passengers p
    JOIN Tickets t ON p.TicketID = t.TicketID
    WHERE t.TrainID = p_TrainID AND t.ScheduleID = p_ScheduleID
      AND p.CoachType = p_CoachType AND p.BookingStatus = 'confirmed'
      AND t.JourneyDate = p_JourneyDate;

    -- Count RAC bookings
    SELECT COUNT(*) INTO v_BookedRAC
    FROM Passengers p
    JOIN Tickets t ON p.TicketID = t.TicketID
    WHERE t.TrainID = p_TrainID AND t.ScheduleID = p_ScheduleID
      AND p.CoachType = p_CoachType AND p.BookingStatus = 'RAC'
      AND t.JourneyDate = p_JourneyDate;

    -- Count WL bookings
    SELECT COUNT(*) INTO v_WLCount
    FROM Passengers p
    JOIN Tickets t ON p.TicketID = t.TicketID
    WHERE t.TrainID = p_TrainID AND t.ScheduleID = p_ScheduleID
      AND p.CoachType = p_CoachType AND p.BookingStatus = 'WL'
      AND t.JourneyDate = p_JourneyDate;

    -- Calculate fare
    SELECT Distance INTO v_FromDistance FROM TrainStops
    WHERE ScheduleID = p_ScheduleID AND StationName = p_FromStation;

    SELECT Distance INTO v_ToDistance FROM TrainStops
    WHERE ScheduleID = p_ScheduleID AND StationName = p_ToStation;

    SET v_Distance = v_ToDistance - v_FromDistance;

    SELECT ROUND(BaseFare * v_Distance / 100, 2) INTO v_Fare
    FROM Coaches WHERE TrainID = p_TrainID AND CoachType = p_CoachType LIMIT 1;

    -- Wallet balance check
    IF p_PaymentMethod = 'wallet' THEN
        SELECT Balance INTO v_WalletBalance FROM EWallet WHERE UserID = p_UserID;
        IF v_WalletBalance < v_Fare THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient wallet balance';
        END IF;
    END IF;

    -- Generate PNR
    SET p_PNR = CONCAT('PNR', LPAD(p_TrainID, 4, '0'), DATE_FORMAT(NOW(), '%d%m%y'), LPAD(FLOOR(RAND() * 10000), 4, '0'));

    -- Insert ticket
    INSERT INTO Tickets (
        PNR, UserID, TrainID, ScheduleID, FromStation, ToStation,
        BookingDate, JourneyDate, TotalPassengers, TotalFare,
        PaymentMethod, PaymentID, BookingStatus
    ) VALUES (
        p_PNR, p_UserID, p_TrainID, p_ScheduleID, p_FromStation, p_ToStation,
        NOW(), p_JourneyDate, 1, v_Fare,
        p_PaymentMethod, p_PaymentID, 'confirmed'
    );

    SET p_TicketID = LAST_INSERT_ID();

    -- Booking logic
    IF v_BookedConfirmed < v_ConfirmedLimit THEN
        SET v_BookingStatus = 'confirmed';
        -- Fetch available seat from Seats table
		SELECT s.SeatNumber INTO v_SeatAllocation
		FROM Seats s
		JOIN Coaches c ON s.CoachID = c.CoachID
		WHERE c.TrainID = p_TrainID
		  AND c.CoachType = p_CoachType
		  AND s.ScheduleID = p_ScheduleID
		  AND s.JourneyDate = p_JourneyDate
		  AND s.IsAvailable = TRUE
		ORDER BY s.SeatNumber
		LIMIT 1;

		-- Reserve the seat
		UPDATE Seats s
		JOIN Coaches c ON s.CoachID = c.CoachID
		SET s.IsAvailable = FALSE
		WHERE c.TrainID = p_TrainID
		  AND c.CoachType = p_CoachType
		  AND s.ScheduleID = p_ScheduleID
		  AND s.JourneyDate = p_JourneyDate
		  AND s.SeatNumber = v_SeatAllocation;


        UPDATE Coaches
        SET AvailableSeats = AvailableSeats - 1
        WHERE TrainID = p_TrainID AND CoachType = p_CoachType;

    ELSEIF v_BookedRAC < v_RACLimit THEN
        SET v_BookingStatus = 'RAC';
        SET v_RACSeatNo = FLOOR(v_BookedRAC / 2) + v_ConfirmedLimit + 1;
        SET v_SeatAllocation = CONCAT('RAC ', v_BookedRAC + 1, ' (', p_CoachType, '-', v_RACSeatNo, ')');

    ELSE
        IF v_WLCount >= 10 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'REGRET';
        END IF;
        SET v_BookingStatus = 'WL';
        SET v_SeatAllocation = CONCAT('WL ', v_WLCount + 1);
    END IF;

    -- Insert passenger
    INSERT INTO Passengers (
        TicketID, Name, Age, Gender, CoachType, SeatAllocation, BookingStatus
    )
    VALUES (
        p_TicketID, p_PassengerName, p_PassengerAge, p_PassengerGender,
        p_CoachType, v_SeatAllocation, v_BookingStatus
    );

    -- Log transaction
    INSERT INTO Transactions (
        TicketID, UserID, Amount, TransactionType, TransactionDate,
        PaymentMethod, PaymentStatus, Remarks
    )
    VALUES (
        p_TicketID, p_UserID, v_Fare, 'booking', NOW(),
        p_PaymentMethod, 'confirmed', CONCAT('1 Passenger Booking - ', v_BookingStatus)
    );

    COMMIT;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE sp_GenerateSeats()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_CoachID INT;
    DECLARE v_TotalSeats INT;
    DECLARE i INT;
    DECLARE cur CURSOR FOR SELECT CoachID, TotalSeats FROM Coaches;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO v_CoachID, v_TotalSeats;
        IF done THEN
            LEAVE read_loop;
        END IF;

        SET i = 1;
        WHILE i <= v_TotalSeats DO
            INSERT INTO Seats (CoachID, SeatNumber, JourneyDate, ScheduleID)
            SELECT v_CoachID, CONCAT('S', i), CURDATE(), s.ScheduleID
            FROM TrainSchedule s
            WHERE s.TrainID = (SELECT TrainID FROM Coaches WHERE CoachID = v_CoachID LIMIT 1);
            SET i = i + 1;
        END WHILE;
    END LOOP;
    CLOSE cur;
END$$

DELIMITER ;

drop procedure sp_BookTicket1;

DELIMITER $$

CREATE PROCEDURE sp_BookTicket1(
    IN p_UserID INT,
    IN p_TrainID INT,
    IN p_ScheduleID INT,
    IN p_FromStation VARCHAR(50),
    IN p_ToStation VARCHAR(50),
    IN p_JourneyDate DATE,
    IN p_CoachType VARCHAR(10),
    IN p_PassengerName VARCHAR(50),
    IN p_PassengerAge INT,
    IN p_PassengerGender CHAR(1),
    IN p_PaymentMethod VARCHAR(20),
    IN p_PaymentID INT,
    OUT p_PNR VARCHAR(20),
    OUT p_TicketID INT
)
BEGIN
    DECLARE v_TotalSeats INT;
    DECLARE v_BookedConfirmed INT;
    DECLARE v_BookedRAC INT;
    DECLARE v_WLCount INT;
    DECLARE v_Fare DECIMAL(10,2);
    DECLARE v_WalletBalance DECIMAL(10,2);
    DECLARE v_FromDistance INT;
    DECLARE v_ToDistance INT;
    DECLARE v_Distance INT;
    DECLARE v_BookingStatus VARCHAR(20);
    DECLARE v_SeatAllocation VARCHAR(20);
    DECLARE v_RACSeatNo INT;
    DECLARE v_CoachID INT;

    START TRANSACTION;

    -- Get total seats and CoachID
    SELECT TotalSeats, CoachID INTO v_TotalSeats, v_CoachID
    FROM Coaches
    WHERE TrainID = p_TrainID AND CoachType = p_CoachType
    LIMIT 1;

    -- Count confirmed bookings
    SELECT COUNT(*) INTO v_BookedConfirmed
    FROM Passengers p
    JOIN Tickets t ON p.TicketID = t.TicketID
    WHERE t.TrainID = p_TrainID
      AND t.ScheduleID = p_ScheduleID
      AND p.CoachType = p_CoachType
      AND p.BookingStatus = 'confirmed'
      AND t.JourneyDate = p_JourneyDate;

    -- Count RAC bookings
    SELECT COUNT(*) INTO v_BookedRAC
    FROM Passengers p
    JOIN Tickets t ON p.TicketID = t.TicketID
    WHERE t.TrainID = p_TrainID
      AND t.ScheduleID = p_ScheduleID
      AND p.CoachType = p_CoachType
      AND p.BookingStatus = 'RAC'
      AND t.JourneyDate = p_JourneyDate;

    -- Count WL bookings
    SELECT COUNT(*) INTO v_WLCount
    FROM Passengers p
    JOIN Tickets t ON p.TicketID = t.TicketID
    WHERE t.TrainID = p_TrainID
      AND t.ScheduleID = p_ScheduleID
      AND p.CoachType = p_CoachType
      AND p.BookingStatus = 'WL'
      AND t.JourneyDate = p_JourneyDate;

    -- Calculate fare
    SELECT Distance INTO v_FromDistance FROM TrainStops
    WHERE ScheduleID = p_ScheduleID AND StationName = p_FromStation;

    SELECT Distance INTO v_ToDistance FROM TrainStops
    WHERE ScheduleID = p_ScheduleID AND StationName = p_ToStation;

    SET v_Distance = v_ToDistance - v_FromDistance;

    SELECT ROUND(BaseFare * v_Distance / 100, 2) INTO v_Fare
    FROM Coaches WHERE TrainID = p_TrainID AND CoachType = p_CoachType LIMIT 1;

    -- Wallet check
    IF p_PaymentMethod = 'wallet' THEN
        SELECT Balance INTO v_WalletBalance FROM EWallet WHERE UserID = p_UserID;
        IF v_WalletBalance < v_Fare THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient wallet balance';
        END IF;
    END IF;

    -- Generate PNR
    SET p_PNR = CONCAT('PNR', LPAD(p_TrainID, 4, '0'), DATE_FORMAT(NOW(), '%d%m%y'), LPAD(FLOOR(RAND() * 10000), 4, '0'));

    -- Insert ticket
    INSERT INTO Tickets (
        PNR, UserID, TrainID, ScheduleID, FromStation, ToStation,
        BookingDate, JourneyDate, TotalPassengers, TotalFare,
        PaymentMethod, PaymentID, BookingStatus
    ) VALUES (
        p_PNR, p_UserID, p_TrainID, p_ScheduleID, p_FromStation, p_ToStation,
        NOW(), p_JourneyDate, 1, v_Fare,
        p_PaymentMethod, p_PaymentID, 'confirmed'
    );

    SET p_TicketID = LAST_INSERT_ID();

    -- Booking logic
    IF v_BookedConfirmed < FLOOR(v_TotalSeats * 0.8) THEN
        SET v_BookingStatus = 'confirmed';

        -- Assign available seat from Seats table
        SELECT SeatNumber INTO v_SeatAllocation
        FROM Seats
        WHERE CoachID = v_CoachID
          AND ScheduleID = p_ScheduleID
          AND JourneyDate = p_JourneyDate
          AND IsAvailable = TRUE
        ORDER BY SeatNumber
        LIMIT 1;

        IF v_SeatAllocation IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No available seat found in seat table';
        END IF;

        -- Reserve the seat
        UPDATE Seats
        SET IsAvailable = FALSE
        WHERE CoachID = v_CoachID
          AND SeatNumber = v_SeatAllocation
          AND ScheduleID = p_ScheduleID
          AND JourneyDate = p_JourneyDate;

        -- Update Coaches availability
        UPDATE Coaches
        SET AvailableSeats = AvailableSeats - 1
        WHERE CoachID = v_CoachID;

    ELSEIF v_BookedRAC < (v_TotalSeats - FLOOR(v_TotalSeats * 0.8)) * 2 THEN
        SET v_BookingStatus = 'RAC';
        SET v_RACSeatNo = FLOOR(v_BookedRAC / 2) + FLOOR(v_TotalSeats * 0.8) + 1;
        SET v_SeatAllocation = CONCAT('RAC ', v_BookedRAC + 1, ' (', p_CoachType, '-', v_RACSeatNo, ')');

    ELSE
        IF v_WLCount >= 10 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'REGRET';
        END IF;
        SET v_BookingStatus = 'WL';
        SET v_SeatAllocation = CONCAT('WL ', v_WLCount + 1);
    END IF;

    -- Insert passenger
    INSERT INTO Passengers (
        TicketID, Name, Age, Gender, CoachType, SeatAllocation, BookingStatus
    )
    VALUES (
        p_TicketID, p_PassengerName, p_PassengerAge, p_PassengerGender,
        p_CoachType, v_SeatAllocation, v_BookingStatus
    );

    -- Log transaction
    INSERT INTO Transactions (
        TicketID, UserID, Amount, TransactionType, TransactionDate,
        PaymentMethod, PaymentStatus, Remarks
    )
    VALUES (
        p_TicketID, p_UserID, v_Fare, 'booking', NOW(),
        p_PaymentMethod, 'confirmed', CONCAT('1 Passenger Booking - ', v_BookingStatus)
    );

    COMMIT;
END$$

DELIMITER ;


-- NEW

DELIMITER $$

CREATE PROCEDURE sp_BookTicket1(
    IN p_UserID INT,
    IN p_TrainID INT,
    IN p_ScheduleID INT,
    IN p_FromStation VARCHAR(50),
    IN p_ToStation VARCHAR(50),
    IN p_JourneyDate DATE,
    IN p_CoachType VARCHAR(10),
    IN p_PassengerName VARCHAR(50),
    IN p_PassengerAge INT,
    IN p_PassengerGender CHAR(1),
    IN p_PaymentMethod VARCHAR(20),
    IN p_PaymentID INT,
    OUT p_PNR VARCHAR(20),
    OUT p_TicketID INT
)
BEGIN
    DECLARE v_TotalSeats INT;
    DECLARE v_BookedConfirmed INT;
    DECLARE v_BookedRAC INT;
    DECLARE v_WLCount INT;
    DECLARE v_Fare DECIMAL(10,2);
    DECLARE v_WalletBalance DECIMAL(10,2);
    DECLARE v_FromDistance INT;
    DECLARE v_ToDistance INT;
    DECLARE v_Distance INT;
    DECLARE v_BookingStatus VARCHAR(20);
    DECLARE v_SeatAllocation VARCHAR(20);
    DECLARE v_RACSeatNo INT;

    START TRANSACTION;

    -- Get total seats in the coach
    SELECT TotalSeats INTO v_TotalSeats
    FROM Coaches
    WHERE TrainID = p_TrainID AND CoachType = p_CoachType
    LIMIT 1;

    -- Count confirmed bookings
    SELECT COUNT(*) INTO v_BookedConfirmed
    FROM Passengers p
    JOIN Tickets t ON p.TicketID = t.TicketID
    WHERE t.TrainID = p_TrainID
      AND t.ScheduleID = p_ScheduleID
      AND p.CoachType = p_CoachType
      AND p.BookingStatus = 'confirmed'
      AND t.JourneyDate = p_JourneyDate;

    -- Count RAC bookings
    SELECT COUNT(*) INTO v_BookedRAC
    FROM Passengers p
    JOIN Tickets t ON p.TicketID = t.TicketID
    WHERE t.TrainID = p_TrainID
      AND t.ScheduleID = p_ScheduleID
      AND p.CoachType = p_CoachType
      AND p.BookingStatus = 'RAC'
      AND t.JourneyDate = p_JourneyDate;

    -- Count WL bookings
    SELECT COUNT(*) INTO v_WLCount
    FROM Passengers p
    JOIN Tickets t ON p.TicketID = t.TicketID
    WHERE t.TrainID = p_TrainID
      AND t.ScheduleID = p_ScheduleID
      AND p.CoachType = p_CoachType
      AND p.BookingStatus = 'WL'
      AND t.JourneyDate = p_JourneyDate;

    -- Calculate fare
    SELECT Distance INTO v_FromDistance FROM TrainStops
    WHERE ScheduleID = p_ScheduleID AND StationName = p_FromStation;

    SELECT Distance INTO v_ToDistance FROM TrainStops
    WHERE ScheduleID = p_ScheduleID AND StationName = p_ToStation;

    SET v_Distance = v_ToDistance - v_FromDistance;

    SELECT ROUND(BaseFare * v_Distance / 100, 2) INTO v_Fare
    FROM Coaches WHERE TrainID = p_TrainID AND CoachType = p_CoachType LIMIT 1;

    -- Wallet check
    IF p_PaymentMethod = 'wallet' THEN
        SELECT Balance INTO v_WalletBalance FROM EWallet WHERE UserID = p_UserID;
        IF v_WalletBalance < v_Fare THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient wallet balance';
        END IF;
    END IF;

    -- Generate PNR
    SET p_PNR = CONCAT('PNR', LPAD(p_TrainID, 4, '0'), DATE_FORMAT(NOW(), '%d%m%y'), LPAD(FLOOR(RAND() * 10000), 4, '0'));

    -- Insert ticket
    INSERT INTO Tickets (
        PNR, UserID, TrainID, ScheduleID, FromStation, ToStation,
        BookingDate, JourneyDate, TotalPassengers, TotalFare,
        PaymentMethod, PaymentID, BookingStatus
    ) VALUES (
        p_PNR, p_UserID, p_TrainID, p_ScheduleID, p_FromStation, p_ToStation,
        NOW(), p_JourneyDate, 1, v_Fare,
        p_PaymentMethod, p_PaymentID, 'confirmed'
    );

    SET p_TicketID = LAST_INSERT_ID();

    -- Booking logic
    IF v_BookedConfirmed < FLOOR(v_TotalSeats * 0.8) THEN
        SET v_BookingStatus = 'confirmed';
        SET v_SeatAllocation = CONCAT(p_CoachType, '-', v_BookedConfirmed + 1);

        -- Decrease available seats only for confirmed
        UPDATE Coaches
        SET AvailableSeats = AvailableSeats - 1
        WHERE TrainID = p_TrainID AND CoachType = p_CoachType;
        
    ELSEIF v_BookedRAC < (v_TotalSeats - FLOOR(v_TotalSeats * 0.8)) * 2 THEN
        SET v_BookingStatus = 'RAC';
        -- 2 RACs share one seat: determine seat number
        SET v_RACSeatNo = FLOOR(v_BookedRAC / 2) + FLOOR(v_TotalSeats * 0.8) + 1;
        SET v_SeatAllocation = CONCAT('RAC ', v_BookedRAC + 1, ' (', p_CoachType, '-', v_RACSeatNo, ')');
        
    ELSE
        IF v_WLCount >= 10 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'REGRET';
        END IF;
        SET v_BookingStatus = 'WL';
        SET v_SeatAllocation = CONCAT('WL ', v_WLCount + 1);
    END IF;

    -- Insert passenger
    INSERT INTO Passengers (
        TicketID, Name, Age, Gender, CoachType, SeatAllocation, BookingStatus
    )
    VALUES (
        p_TicketID, p_PassengerName, p_PassengerAge, p_PassengerGender,
        p_CoachType, v_SeatAllocation, v_BookingStatus
    );

    -- Log transaction
    INSERT INTO Transactions (
        TicketID, UserID, Amount, TransactionType, TransactionDate,
        PaymentMethod, PaymentStatus, Remarks
    )
    VALUES (
        p_TicketID, p_UserID, v_Fare, 'booking', NOW(),
        p_PaymentMethod, 'confirmed', CONCAT('1 Passenger Booking - ', v_BookingStatus)
    );

    COMMIT;
END$$

DELIMITER ;

drop procedure sp_CancelTicket;
-- NEW 
DELIMITER $$

CREATE PROCEDURE sp_CancelTicket(
    IN p_TicketID INT,
    IN p_UserID INT,
    IN p_RefundTo VARCHAR(20),
    OUT p_RefundAmount DECIMAL(10,2),
    OUT p_Status VARCHAR(50)
)
BEGIN
    DECLARE v_BookingStatus VARCHAR(20);
    DECLARE v_TotalFare DECIMAL(10,2);
    DECLARE v_JourneyDate DATE;
    DECLARE v_TrainID INT;
    DECLARE v_CoachType VARCHAR(10);
    DECLARE v_DaysToJourney INT;
    DECLARE v_RefundPercentage INT;
    DECLARE v_TicketExists INT DEFAULT 0;
    DECLARE v_SeatNumber VARCHAR(10);
    DECLARE v_CoachID INT;
    DECLARE v_ScheduleID INT;

    START TRANSACTION;

    -- Verify ticket
    SELECT COUNT(*) INTO v_TicketExists
    FROM Tickets
    WHERE TicketID = p_TicketID AND UserID = p_UserID;

    IF v_TicketExists = 0 THEN
        SET p_Status = 'Ticket not found';
        SET p_RefundAmount = 0;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ticket not found';
    END IF;

    -- Get booking info
    SELECT BookingStatus, TotalFare, JourneyDate, TrainID
    INTO v_BookingStatus, v_TotalFare, v_JourneyDate, v_TrainID
    FROM Tickets
    WHERE TicketID = p_TicketID AND UserID = p_UserID;

    -- Prevent duplicate cancellation
    IF v_BookingStatus = 'cancelled' THEN
        SET p_Status = 'Already cancelled';
        SET p_RefundAmount = 0;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ticket already cancelled';
    END IF;

    -- Get coach type and seat number
    SELECT CoachType, SUBSTRING_INDEX(SeatAllocation, '-', -1) INTO v_CoachType, v_SeatNumber
    FROM Passengers
    WHERE TicketID = p_TicketID
    LIMIT 1;

    -- Get CoachID and ScheduleID
    SELECT CoachID INTO v_CoachID
    FROM Coaches
    WHERE TrainID = v_TrainID AND CoachType = v_CoachType
    LIMIT 1;

    SELECT ScheduleID INTO v_ScheduleID
    FROM TrainSchedule
    WHERE TrainID = v_TrainID
    LIMIT 1;

    -- Refund calculation
    SET v_DaysToJourney = DATEDIFF(v_JourneyDate, CURRENT_DATE());

    IF v_DaysToJourney > 7 THEN
        SET v_RefundPercentage = 90;
    ELSEIF v_DaysToJourney > 3 THEN
        SET v_RefundPercentage = 75;
    ELSEIF v_DaysToJourney > 1 THEN
        SET v_RefundPercentage = 50;
    ELSE
        SET v_RefundPercentage = 25;
    END IF;

    SET p_RefundAmount = ROUND((v_TotalFare * v_RefundPercentage) / 100, 2);

    -- Cancel ticket
    UPDATE Tickets
    SET BookingStatus = 'cancelled'
    WHERE TicketID = p_TicketID AND UserID = p_UserID;

    UPDATE Passengers
    SET BookingStatus = 'cancelled'
    WHERE TicketID = p_TicketID;

    -- If confirmed, free seat and adjust availability
    IF v_BookingStatus = 'confirmed' THEN
        UPDATE Seats
        SET IsAvailable = TRUE
        WHERE CoachID = v_CoachID
          AND SeatNumber = v_SeatNumber
          AND JourneyDate = v_JourneyDate
          AND ScheduleID = v_ScheduleID;

        UPDATE Coaches
        SET AvailableSeats = AvailableSeats + 1
        WHERE CoachID = v_CoachID;
    END IF;

    -- Insert cancellation record
    INSERT INTO Cancellation (
        TicketID, CancellationDate, RefundAmount, RefundStatus, RefundTo
    ) VALUES (
        p_TicketID, NOW(), p_RefundAmount, 'processed', p_RefundTo
    );

    -- Log transaction
    INSERT INTO Transactions (
        TicketID, UserID, Amount, TransactionType,
        TransactionDate, PaymentMethod, PaymentStatus, Remarks
    ) VALUES (
        p_TicketID, p_UserID, p_RefundAmount, 'cancellation',
        NOW(), p_RefundTo, 'confirmed',
        CONCAT('Refund at ', v_RefundPercentage, '% of original fare')
    );

    -- Shift RAC and WL
    CALL sp_HandleRACandWLShifts(v_CoachType, v_CoachID, v_ScheduleID, v_JourneyDate, v_SeatNumber);

    SET p_Status = 'Ticket cancelled and RAC/WL adjusted';
    COMMIT;
END$$

-- saka laka boom boom
DELIMITER $$

CREATE PROCEDURE sp_CancelTicket(
    IN p_TicketID INT,
    IN p_UserID INT,
    IN p_RefundTo VARCHAR(20),
    OUT p_RefundAmount DECIMAL(10,2),
    OUT p_Status VARCHAR(50)
)
BEGIN
    DECLARE v_BookingStatus VARCHAR(20);
    DECLARE v_TotalFare DECIMAL(10,2);
    DECLARE v_JourneyDate DATE;
    DECLARE v_TrainID INT;
    DECLARE v_CoachType VARCHAR(10);
    DECLARE v_CoachID INT;
    DECLARE v_ScheduleID INT;
    DECLARE v_FreedSeat VARCHAR(10);
    DECLARE v_DaysToJourney INT;
    DECLARE v_RefundPercentage INT;
    DECLARE v_TicketExists INT DEFAULT 0;

    START TRANSACTION;

    -- Verify ticket
    SELECT COUNT(*) INTO v_TicketExists
    FROM Tickets
    WHERE TicketID = p_TicketID AND UserID = p_UserID;

    IF v_TicketExists = 0 THEN
        SET p_Status = 'Ticket not found';
        SET p_RefundAmount = 0;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ticket not found';
    END IF;

    -- Get booking info
    SELECT BookingStatus, TotalFare, JourneyDate, TrainID, ScheduleID
    INTO v_BookingStatus, v_TotalFare, v_JourneyDate, v_TrainID, v_ScheduleID
    FROM Tickets
    WHERE TicketID = p_TicketID AND UserID = p_UserID;

    -- Prevent duplicate cancellation
    IF v_BookingStatus = 'cancelled' THEN
        SET p_Status = 'Already cancelled';
        SET p_RefundAmount = 0;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ticket already cancelled';
    END IF;

    -- Get coach and seat info
    SELECT CoachType, CoachID, SeatNumber
    INTO v_CoachType, v_CoachID, v_FreedSeat
    FROM Passengers
    WHERE TicketID = p_TicketID
    LIMIT 1;

    -- Refund calculation
    SET v_DaysToJourney = DATEDIFF(v_JourneyDate, CURRENT_DATE());

    IF v_DaysToJourney > 7 THEN
        SET v_RefundPercentage = 90;
    ELSEIF v_DaysToJourney > 3 THEN
        SET v_RefundPercentage = 75;
    ELSEIF v_DaysToJourney > 1 THEN
        SET v_RefundPercentage = 50;
    ELSE
        SET v_RefundPercentage = 25;
    END IF;

    SET p_RefundAmount = ROUND((v_TotalFare * v_RefundPercentage) / 100, 2);

    -- Cancel ticket and passengers
    UPDATE Tickets
    SET BookingStatus = 'cancelled'
    WHERE TicketID = p_TicketID AND UserID = p_UserID;

    UPDATE Passengers
    SET BookingStatus = 'cancelled'
    WHERE TicketID = p_TicketID;

    -- Mark seat as available in Seats table
    IF v_BookingStatus = 'confirmed' THEN
        UPDATE Seats
        SET IsAvailable = 1
        WHERE CoachID = v_CoachID AND ScheduleID = v_ScheduleID AND JourneyDate = v_JourneyDate AND SeatNumber = v_FreedSeat;
    END IF;

    -- Insert into Cancellation
    INSERT INTO Cancellation (
        TicketID, CancellationDate, RefundAmount, RefundStatus, RefundTo
    ) VALUES (
        p_TicketID, NOW(), p_RefundAmount, 'processed', p_RefundTo
    );

    -- Log transaction
    INSERT INTO Transactions (
        TicketID, UserID, Amount, TransactionType,
        TransactionDate, PaymentMethod, PaymentStatus, Remarks
    ) VALUES (
        p_TicketID, p_UserID, p_RefundAmount, 'cancellation',
        NOW(), p_RefundTo, 'confirmed',
        CONCAT('Refund at ', v_RefundPercentage, '% of original fare')
    );

    -- Handle RAC and WL shifts
    CALL sp_HandleRACandWLShifts(v_CoachType, v_CoachID, v_ScheduleID, v_JourneyDate, v_FreedSeat);

    SET p_Status = 'Ticket cancelled and RAC/WL adjusted';
    COMMIT;
END$$

DELIMITER ;


-- OLD 
drop procedure sp_CancelTicket;

DELIMITER $$
CREATE PROCEDURE sp_CancelTicket(
    IN p_TicketID INT,
    IN p_UserID INT,
    IN p_RefundTo VARCHAR(20), -- 'wallet' or 'original_payment'
    OUT p_RefundAmount DECIMAL(10,2),
    OUT p_Status VARCHAR(50)
)
BEGIN
    DECLARE v_BookingStatus VARCHAR(20);
    DECLARE v_TotalFare DECIMAL(10,2);
    DECLARE v_JourneyDate DATE;
    DECLARE v_BookingDate TIMESTAMP;
    DECLARE v_TrainID INT;
    DECLARE v_DaysToJourney INT;
    DECLARE v_RefundPercentage INT;
    DECLARE v_TotalPassengers INT;
    DECLARE v_CoachType VARCHAR(10);
    
    -- Start transaction
    START TRANSACTION;
    
    -- Check if ticket exists and belongs to user
    SELECT 
        BookingStatus, 
        TotalFare,
        JourneyDate,
        BookingDate,
        TrainID,
        TotalPassengers
    INTO 
        v_BookingStatus, 
        v_TotalFare,
        v_JourneyDate,
        v_BookingDate,
        v_TrainID,
        v_TotalPassengers
    FROM Tickets
    WHERE TicketID = p_TicketID AND UserID = p_UserID;
    
    -- Check if ticket was found
    IF v_BookingStatus IS NULL THEN
        SET p_Status = 'Ticket not found or does not belong to user';
        SET p_RefundAmount = 0;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Ticket not found or does not belong to user';
    END IF;
    
    -- Check if ticket is already cancelled
    IF v_BookingStatus = 'cancelled' THEN
        SET p_Status = 'Ticket already cancelled';
        SET p_RefundAmount = 0;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Ticket already cancelled';
    END IF;
    
    -- Calculate days to journey
    SET v_DaysToJourney = DATEDIFF(v_JourneyDate, CURRENT_DATE());
    
    -- Calculate refund percentage based on days to journey
    IF v_DaysToJourney > 7 THEN
        SET v_RefundPercentage = 90; -- 90% refund if more than 7 days to journey
    ELSEIF v_DaysToJourney > 3 THEN
        SET v_RefundPercentage = 75; -- 75% refund if 4-7 days to journey
    ELSEIF v_DaysToJourney > 1 THEN
        SET v_RefundPercentage = 50; -- 50% refund if 2-3 days to journey
    ELSE
        SET v_RefundPercentage = 25; -- 25% refund if less than 48 hours to journey
    END IF;
    
    -- Calculate refund amount
    SET p_RefundAmount = ROUND((v_TotalFare * v_RefundPercentage) / 100, 2);
    
    -- Update ticket status to cancelled
    UPDATE Tickets
    SET BookingStatus = 'cancelled'
    WHERE TicketID = p_TicketID;
    
    -- Get coach type from first passenger
    SELECT CoachType INTO v_CoachType
    FROM Passengers
    WHERE TicketID = p_TicketID
    LIMIT 1;
    
    -- Update available seats
    CALL sp_HandleRACandWLShifts(v_CoachType);
    
    -- Insert cancellation record
    INSERT INTO Cancellation (
        TicketID, CancellationDate, RefundAmount, RefundStatus, RefundTo
    )
    VALUES (
        p_TicketID, NOW(), p_RefundAmount, 'processed', p_RefundTo
    );
    
    -- Create transaction record for cancellation
    INSERT INTO Transactions (
        TicketID, UserID, Amount, TransactionType,
        TransactionDate, PaymentMethod, PaymentStatus, Remarks
    )
    VALUES (
        p_TicketID, p_UserID, p_RefundAmount, 'cancellation',
        NOW(), p_RefundTo, 'confirmed', CONCAT('Refund at ', v_RefundPercentage, '% of original fare')
    );
    
    -- Set status as success
    SET p_Status = 'Ticket cancelled successfully';
    
    COMMIT;
END$$
DELIMITER ;


-- rac wl handling

drop procedure sp_HandleRACandWLShifts;

-- boom bam digi digi

DELIMITER $$

CREATE PROCEDURE sp_HandleRACandWLShifts(
    IN p_CoachType VARCHAR(10),
    IN p_CoachID INT,
    IN p_ScheduleID INT,
    IN p_JourneyDate DATE,
    IN p_FreedSeat VARCHAR(10)
)
BEGIN
    DECLARE v_RAC_PassengerID INT;
    DECLARE v_WL_PassengerID INT;

    -- Promote RAC 1 to confirmed
    SELECT PassengerID INTO v_RAC_PassengerID
    FROM Passengers
    WHERE BookingStatus = 'RAC' AND CoachType = p_CoachType
    ORDER BY SeatAllocation
    LIMIT 1;

    IF v_RAC_PassengerID IS NOT NULL THEN
        -- Update seat status
        UPDATE Seats
        SET IsAvailable = 0
        WHERE CoachID = p_CoachID AND ScheduleID = p_ScheduleID AND JourneyDate = p_JourneyDate AND SeatNumber = p_FreedSeat;

        -- Promote RAC to confirmed
        UPDATE Passengers
        SET BookingStatus = 'confirmed', SeatNumber = p_FreedSeat
        WHERE PassengerID = v_RAC_PassengerID;
    END IF;

    -- Shift remaining RAC passengers down (RAC 2 → RAC 1, RAC 3 → RAC 2, ...)
    UPDATE Passengers
    SET SeatAllocation = CONCAT('RAC ', CAST(SUBSTRING_INDEX(SeatAllocation, ' ', -1) - 1 AS CHAR))
    WHERE BookingStatus = 'RAC' AND CAST(SUBSTRING_INDEX(SeatAllocation, ' ', -1) AS UNSIGNED) > 1;

    -- Promote WL 1 to RAC 7
    SELECT PassengerID INTO v_WL_PassengerID
    FROM Passengers
    WHERE BookingStatus = 'WL' AND SeatAllocation = 'WL 1' AND CoachType = p_CoachType
    LIMIT 1;

    IF v_WL_PassengerID IS NOT NULL THEN
        UPDATE Passengers
        SET BookingStatus = 'RAC', SeatAllocation = 'RAC 7'
        WHERE PassengerID = v_WL_PassengerID;
    END IF;

    -- Shift remaining WL passengers down (WL 2 → WL 1, etc.)
    UPDATE Passengers
    SET SeatAllocation = CONCAT('WL ', CAST(SUBSTRING_INDEX(SeatAllocation, ' ', -1) - 1 AS CHAR))
    WHERE BookingStatus = 'WL' AND CAST(SUBSTRING_INDEX(SeatAllocation, ' ', -1) AS UNSIGNED) > 1;
END$$

DELIMITER ;


DELIMITER $$

CREATE PROCEDURE sp_HandleRACandWLShifts(
    IN p_CoachType VARCHAR(10),
    IN p_CoachID INT,
    IN p_ScheduleID INT,
    IN p_JourneyDate DATE,
    IN p_FreedSeat VARCHAR(10)
)
BEGIN
    DECLARE v_PromotedPassengerID INT;

    -- Promote RAC 1 to confirmed and assign freed seat
    SELECT p.PassengerID INTO v_PromotedPassengerID
    FROM Passengers p
    JOIN Tickets t ON p.TicketID = t.TicketID
    WHERE p.BookingStatus = 'RAC'
      AND p.CoachType = p_CoachType
      AND t.JourneyDate = p_JourneyDate
    ORDER BY CAST(SUBSTRING_INDEX(p.SeatAllocation, ' ', -1) AS UNSIGNED)
    LIMIT 1;

    IF v_PromotedPassengerID IS NOT NULL THEN
        -- Update booking status and assign the freed seat
        UPDATE Passengers
        SET BookingStatus = 'confirmed',
            SeatAllocation = CONCAT(p_CoachType, '-', p_FreedSeat)
        WHERE PassengerID = v_PromotedPassengerID;

        -- Mark seat as unavailable
        UPDATE Seats
        SET IsAvailable = FALSE
        WHERE CoachID = p_CoachID
          AND SeatNumber = p_FreedSeat
          AND ScheduleID = p_ScheduleID
          AND JourneyDate = p_JourneyDate;
    END IF;

    -- Shift remaining RAC numbers down
    UPDATE Passengers
    SET SeatAllocation = CONCAT('RAC ', CAST(SUBSTRING_INDEX(SeatAllocation, ' ', -1) AS UNSIGNED) - 1)
    WHERE BookingStatus = 'RAC'
      AND CoachType = p_CoachType
      AND CAST(SUBSTRING_INDEX(SeatAllocation, ' ', -1) AS UNSIGNED) > 1;

    -- Promote WL 1 to RAC 7
    UPDATE Passengers
    SET BookingStatus = 'RAC', SeatAllocation = 'RAC 7'
    WHERE BookingStatus = 'WL'
      AND SeatAllocation = 'WL 1'
      AND CoachType = p_CoachType;

    -- Shift WL numbers down
    UPDATE Passengers
    SET SeatAllocation = CONCAT('WL ', CAST(SUBSTRING_INDEX(SeatAllocation, ' ', -1) AS UNSIGNED) - 1)
    WHERE BookingStatus = 'WL'
      AND CAST(SUBSTRING_INDEX(SeatAllocation, ' ', -1) AS UNSIGNED) > 1
      AND CoachType = p_CoachType;
END$$

DELIMITER ;




DELIMITER $$
CREATE PROCEDURE sp_ViewUserBookings(
    IN p_UserID INT,
    IN p_Status VARCHAR(20), -- 'all', 'active', 'cancelled'
    IN p_FromDate DATE,     -- NULL for no filter
    IN p_ToDate DATE        -- NULL for no filter
)
BEGIN
    -- If dates are NULL, set them to wide range
    SET p_FromDate = IFNULL(p_FromDate, '2000-01-01');
    SET p_ToDate = IFNULL(p_ToDate, '2099-12-31');
    
    SELECT 
        t.TicketID,
        t.PNR,
        tr.TrainNumber,
        tr.TrainName,
        t.FromStation,
        t.ToStation,
        t.JourneyDate,
        t.BookingDate,
        t.TotalPassengers,
        t.TotalFare,
        t.BookingStatus,
        t.PaymentMethod,
        (SELECT GROUP_CONCAT(p.Name SEPARATOR ', ') 
         FROM Passengers p
         WHERE p.TicketID = t.TicketID) AS PassengerNames,
        (SELECT GROUP_CONCAT(p.SeatAllocation SEPARATOR ', ') 
         FROM Passengers p
         WHERE p.TicketID = t.TicketID) AS SeatAllocations,
        CASE
            WHEN c.RefundAmount IS NOT NULL THEN c.RefundAmount
            ELSE 0
        END AS RefundAmount,
        CASE
            WHEN c.RefundStatus IS NOT NULL THEN c.RefundStatus
            ELSE 'N/A'
        END AS RefundStatus
    FROM 
        Tickets t
    JOIN 
        Trains tr ON t.TrainID = tr.TrainID
    LEFT JOIN 
        Cancellation c ON t.TicketID = c.TicketID
    WHERE 
        t.UserID = p_UserID
        AND (p_Status = 'all' OR 
            (p_Status = 'active' AND t.BookingStatus = 'confirmed') OR
            (p_Status = 'cancelled' AND t.BookingStatus = 'cancelled'))
        AND t.JourneyDate BETWEEN p_FromDate AND p_ToDate
    ORDER BY 
        t.JourneyDate DESC, t.BookingDate DESC;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_UserLogout(
    IN p_UserID INT,
    OUT p_Status VARCHAR(50)
)
BEGIN
    -- In a real application, this would handle session management
    -- Here we just return a success message since MySQL doesn't handle sessions
    SET p_Status = 'User logged out successfully';
END$$
DELIMITER ;

select * from Coaches;

-- Complete the coach insertion for all trains
-- For each train, add 1A, 2A, 3A, SL (Sleeper), and GN (General) coaches

INSERT INTO Trains (TrainNumber, TrainName, TrainType) VALUES
('12301', 'Rajdhani Express', 'Superfast'),
('12002', 'Shatabdi Express', 'Shatabdi'),
('12259', 'Duronto Express', 'Superfast'),
('12075', 'Jan Shatabdi', 'Janshatabdi'),
('12203', 'Garib Rath', 'Superfast'),
('12649', 'Sampark Kranti', 'Superfast'),
('22435', 'Vande Bharat', 'Vande Bharat'),
('82501', 'Tejas Express', 'Tejas'),
('12957', 'Humsafar Express', 'Humsafar'),
('12010', 'Intercity Express', 'Express'),
('12931', 'Double Decker', 'Superfast'),
('12821', 'Antyodaya Express', 'Antyodaya'),
('12233', 'Yuva Express', 'Superfast'),
('12380', 'Kavi Guru Express', 'Express'),
('22121', 'Mahamana Express', 'Superfast'),
('12050', 'Gatimaan Express', 'Gatimaan'),
('12953', 'AC Express', 'Superfast'),
('12701', 'Janmabhoomi Express', 'Express'),
('12657', 'Mysore Express', 'Express'),
('12679', 'Chennai Express', 'Superfast');


INSERT INTO Coaches (TrainID, CoachType, CoachNumber, TotalSeats, AvailableSeats, BaseFare) VALUES
-- Train 1: Rajdhani Express
(1, '1A', 'A1', 18, 18, 3.50),
(1, '2A', 'B1', 46, 46, 2.50),
(1, '3A', 'C1', 64, 64, 1.75),
(1, '3A', 'C2', 64, 64, 1.75),
(1, 'SL', 'S1', 72, 72, 1.00),
(1, 'SL', 'S2', 72, 72, 1.00),
(1, 'GN', 'G1', 90, 90, 0.60),

-- Train 2: Shatabdi Express
(2, 'EC', 'E1', 56, 56, 2.75),
(2, 'CC', 'C1', 78, 78, 2.00),
(2, 'CC', 'C2', 78, 78, 2.00),
(2, '2S', 'D1', 78, 78, 1.25),
(2, 'GN', 'G1', 90, 90, 0.60),

-- Train 3: Duronto Express
(3, '1A', 'A1', 18, 18, 3.25),
(3, '2A', 'B1', 46, 46, 2.30),
(3, '3A', 'C1', 64, 64, 1.60),
(3, '3A', 'C2', 64, 64, 1.60),
(3, 'SL', 'S1', 72, 72, 0.90),
(3, 'SL', 'S2', 72, 72, 0.90),
(3, 'GN', 'G1', 90, 90, 0.55),

-- Train 4: Jan Shatabdi
(4, 'CC', 'C1', 78, 78, 1.80),
(4, '2S', 'D1', 78, 78, 1.15),
(4, '2S', 'D2', 78, 78, 1.15),
(4, 'GN', 'G1', 90, 90, 0.50),

-- Train 5: Garib Rath
(5, '3A', 'C1', 64, 64, 1.40),
(5, '3A', 'C2', 64, 64, 1.40),
(5, '3A', 'C3', 64, 64, 1.40),
(5, 'GN', 'G1', 90, 90, 0.45),

-- Add similar patterns for trains 6-20
-- Train 6: Sampark Kranti
(6, '2A', 'B1', 46, 46, 2.20),
(6, '3A', 'C1', 64, 64, 1.55),
(6, 'SL', 'S1', 72, 72, 0.85),
(6, 'SL', 'S2', 72, 72, 0.85),
(6, 'GN', 'G1', 90, 90, 0.50),

-- Train 7: Vande Bharat
(7, 'EC', 'E1', 56, 56, 3.00),
(7, 'EC', 'E2', 56, 56, 3.00),
(7, 'CC', 'C1', 78, 78, 2.20),
(7, 'CC', 'C2', 78, 78, 2.20),

-- Train 8: Tejas Express
(8, 'EC', 'E1', 56, 56, 2.90),
(8, 'CC', 'C1', 78, 78, 2.10),
(8, 'CC', 'C2', 78, 78, 2.10),

-- Train 9: Humsafar Express
(9, '3A', 'C1', 64, 64, 1.65),
(9, '3A', 'C2', 64, 64, 1.65),
(9, '3A', 'C3', 64, 64, 1.65),

-- Train 10: Intercity Express
(10, 'CC', 'C1', 78, 78, 1.75),
(10, '2S', 'D1', 78, 78, 1.10),
(10, '2S', 'D2', 78, 78, 1.10),
(10, 'GN', 'G1', 90, 90, 0.50),

-- Train 11: Double Decker
(11, 'CC', 'C1', 120, 120, 1.85),
(11, 'CC', 'C2', 120, 120, 1.85),
(11, 'CC', 'C3', 120, 120, 1.85),

-- Train 12: Antyodaya Express
(12, '2S', 'D1', 78, 78, 0.95),
(12, '2S', 'D2', 78, 78, 0.95),
(12, '2S', 'D3', 78, 78, 0.95),
(12, 'GN', 'G1', 90, 90, 0.45),

-- Train 13: Yuva Express
(13, 'CC', 'C1', 78, 78, 1.60),
(13, '2S', 'D1', 78, 78, 1.00),
(13, 'GN', 'G1', 90, 90, 0.50),

-- Train 14: Kavi Guru Express
(14, '2A', 'B1', 46, 46, 2.15),
(14, '3A', 'C1', 64, 64, 1.50),
(14, 'SL', 'S1', 72, 72, 0.80),
(14, 'SL', 'S2', 72, 72, 0.80),
(14, 'GN', 'G1', 90, 90, 0.45),

-- Train 15: Mahamana Express
(15, '1A', 'A1', 18, 18, 3.10),
(15, '2A', 'B1', 46, 46, 2.25),
(15, '3A', 'C1', 64, 64, 1.55),
(15, 'SL', 'S1', 72, 72, 0.85),
(15, 'GN', 'G1', 90, 90, 0.50),

-- Train 16: Gatimaan Express
(16, 'EC', 'E1', 56, 56, 3.10),
(16, 'CC', 'C1', 78, 78, 2.30),
(16, 'CC', 'C2', 78, 78, 2.30),

-- Train 17: AC Express
(17, '1A', 'A1', 18, 18, 3.15),
(17, '2A', 'B1', 46, 46, 2.35),
(17, '3A', 'C1', 64, 64, 1.65),
(17, '3A', 'C2', 64, 64, 1.65),

-- Train 18: Janmabhoomi Express
(18, '2A', 'B1', 46, 46, 2.10),
(18, '3A', 'C1', 64, 64, 1.45),
(18, 'SL', 'S1', 72, 72, 0.75),
(18, 'SL', 'S2', 72, 72, 0.75),
(18, 'GN', 'G1', 90, 90, 0.45),

-- Train 19: Mysore Express
(19, '2A', 'B1', 46, 46, 2.05),
(19, '3A', 'C1', 64, 64, 1.40),
(19, 'SL', 'S1', 72, 72, 0.70),
(19, 'SL', 'S2', 72, 72, 0.70),
(19, 'GN', 'G1', 90, 90, 0.40),

-- Train 20: Chennai Express
(20, '1A', 'A1', 18, 18, 3.20),
(20, '2A', 'B1', 46, 46, 2.40),
(20, '3A', 'C1', 64, 64, 1.70),
(20, '3A', 'C2', 64, 64, 1.70),
(20, 'SL', 'S1', 72, 72, 0.95),
(20, 'SL', 'S2', 72, 72, 0.95),
(20, 'GN', 'G1', 90, 90, 0.55);

CALL sp_CreateUser(
    'john_doe',              -- Username
    '1992-05-15',            -- DOB
    'john@example.com',      -- Email
    '9876543210',            -- PhonePrimary
    NULL,                    -- PhoneSecondary
    '4111222233334444',      -- CardNumber
    '12/26',                 -- CardExpiry
    'John Doe',              -- CardHolderName
    'john@upi',              -- UPI_ID
    'normal',                -- UserType
    @newUserID               -- OUT: UserID
);

INSERT INTO TrainSchedule (TrainID, RunningDays, Status) VALUES
(1, 'Mon,Wed,Fri', 'active'),
(2, 'Tue,Thu,Sat', 'active'),
(3, 'Mon,Tue,Wed,Thu,Fri,Sat,Sun', 'active'),
(4, 'Mon,Wed,Fri,Sun', 'active'),
(5, 'Tue,Thu,Sat', 'active'),
(6, 'Mon,Wed,Fri', 'active'),
(7, 'Mon,Tue,Wed,Thu,Fri', 'active'),
(8, 'Sat,Sun', 'active'),
(9, 'Mon,Tue,Wed,Thu,Fri', 'active'),
(10, 'Mon,Tue,Wed,Thu,Fri,Sat,Sun', 'active'),
(11, 'Mon,Wed,Fri', 'active'),
(12, 'Tue,Thu,Sat,Sun', 'active'),
(13, 'Mon,Tue,Wed,Thu,Fri', 'active'),
(14, 'Sun', 'active'),
(15, 'Mon,Wed,Fri', 'active'),
(16, 'Tue,Thu,Sat', 'active'),
(17, 'Mon,Tue,Wed,Thu,Fri,Sat,Sun', 'active'),
(18, 'Mon,Wed,Fri', 'active'),
(19, 'Tue,Thu,Sat,Sun', 'active'),
(20, 'Mon,Tue,Wed,Thu,Fri,Sat,Sun', 'active');

select * from trainschedule;

alter table trainstops add FOREIGN KEY (ScheduleID) REFERENCES TrainSchedule(ScheduleID);

-- Train 1
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(1, 'Delhi', 1, NULL, '06:00:00', 0),
(1, 'Kanpur', 2, '10:00:00', '10:10:00', 440),
(1, 'Lucknow', 3, '11:30:00', '11:40:00', 510),
(1, 'Patna', 4, '16:30:00', NULL, 990);

-- Train 2
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(2, 'Mumbai', 1, NULL, '07:30:00', 0),
(2, 'Pune', 2, '09:45:00', '09:55:00', 150),
(2, 'Nagpur', 3, '16:00:00', '16:10:00', 850),
(2, 'Bhopal', 4, '20:00:00', NULL, 1100);

-- Train 3
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(3, 'Chennai', 1, NULL, '08:30:00', 0),
(3, 'Bangalore', 2, '12:30:00', '12:40:00', 350),
(3, 'Hyderabad', 3, '17:30:00', '17:40:00', 650),
(3, 'Nagpur', 4, '22:30:00', NULL, 950);

-- Train 4
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(4, 'Kolkata', 1, NULL, '16:00:00', 0),
(4, 'Patna', 2, '21:00:00', '21:10:00', 500),
(4, 'Lucknow', 3, '02:00:00', '02:10:00', 900),
(4, 'Delhi', 4, '07:00:00', NULL, 1450);

-- Train 5
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(5, 'Bangalore', 1, NULL, '12:00:00', 0),
(5, 'Hyderabad', 2, '16:30:00', '16:40:00', 400),
(5, 'Nagpur', 3, '22:00:00', '22:10:00', 800),
(5, 'Bhopal', 4, '02:00:00', '02:10:00', 1050),
(5, 'Delhi', 5, '08:00:00', NULL, 1650);

-- Train 6
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(6, 'Mumbai', 1, NULL, '18:00:00', 0),
(6, 'Pune', 2, '20:00:00', '20:10:00', 150),
(6, 'Hyderabad', 3, '04:00:00', '04:10:00', 700),
(6, 'Chennai', 4, '12:00:00', NULL, 1250);

-- Train 7
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(7, 'Delhi', 1, NULL, '14:00:00', 0),
(7, 'Jaipur', 2, '18:00:00', '18:10:00', 300),
(7, 'Ahmedabad', 3, '23:00:00', '23:10:00', 700),
(7, 'Mumbai', 4, '07:00:00', NULL, 1200);

-- Train 8
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(8, 'Chennai', 1, NULL, '06:00:00', 0),
(8, 'Bangalore', 2, '10:00:00', '10:10:00', 350),
(8, 'Mumbai', 3, '22:00:00', NULL, 1200);

-- Train 9
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(9, 'Kolkata', 1, NULL, '09:00:00', 0),
(9, 'Patna', 2, '14:00:00', '14:10:00', 500),
(9, 'Kanpur', 3, '20:00:00', '20:10:00', 950),
(9, 'Delhi', 4, '00:00:00', NULL, 1350);

-- Train 10
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(10, 'Hyderabad', 1, NULL, '07:00:00', 0),
(10, 'Nagpur', 2, '12:00:00', '12:10:00', 500),
(10, 'Bhopal', 3, '16:00:00', '16:10:00', 750),
(10, 'Delhi', 4, '22:00:00', NULL, 1350);

-- Train 11
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(11, 'Delhi', 1, NULL, '15:00:00', 0),
(11, 'Bhopal', 2, '21:00:00', '21:10:00', 600),
(11, 'Nagpur', 3, '01:00:00', '01:10:00', 850),
(11, 'Hyderabad', 4, '06:00:00', NULL, 1350);

-- Train 12
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(12, 'Mumbai', 1, NULL, '21:00:00', 0),
(12, 'Ahmedabad', 2, '04:00:00', '04:10:00', 500),
(12, 'Jaipur', 3, '09:00:00', '09:10:00', 900),
(12, 'Delhi', 4, '13:00:00', NULL, 1200);

-- Train 13
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(13, 'Chennai', 1, NULL, '10:00:00', 0),
(13, 'Hyderabad', 2, '15:00:00', '15:10:00', 500),
(13, 'Nagpur', 3, '20:00:00', '20:10:00', 900),
(13, 'Bhopal', 4, '01:00:00', NULL, 1200);

-- Train 14
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(14, 'Delhi', 1, NULL, '17:00:00', 0),
(14, 'Kanpur', 2, '21:00:00', '21:10:00', 440),
(14, 'Lucknow', 3, '23:00:00', NULL, 510);

-- Train 15
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(15, 'Bangalore', 1, NULL, '05:00:00', 0),
(15, 'Chennai', 2, '09:00:00', NULL, 350);

-- Train 16
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(16, 'Mumbai', 1, NULL, '20:00:00', 0),
(16, 'Nagpur', 2, '03:00:00', '03:10:00', 850),
(16, 'Kolkata', 3, '09:00:00', NULL, 1450);

-- Train 17
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(17, 'Kolkata', 1, NULL, '08:00:00', 0),
(17, 'Patna', 2, '13:00:00', '13:10:00', 500),
(17, 'Delhi', 3, '20:00:00', NULL, 1350);

-- Train 18
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(18, 'Chennai', 1, NULL, '18:00:00', 0),
(18, 'Hyderabad', 2, '22:00:00', '22:10:00', 400),
(18, 'Nagpur', 3, '03:00:00', '03:10:00', 800),
(18, 'Bhopal', 4, '06:00:00', NULL, 1050);

-- Train 19
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(19, 'Delhi', 1, NULL, '06:00:00', 0),
(19, 'Jaipur', 2, '10:00:00', '10:10:00', 300),
(19, 'Ahmedabad', 3, '15:00:00', NULL, 700);

-- Train 20
INSERT INTO TrainStops (ScheduleID, StationName, StopNumber, ArrivalTime, DepartureTime, Distance) VALUES
(20, 'Chennai', 1, NULL, '04:00:00', 0),
(20, 'Bangalore', 2, '08:00:00', '08:10:00', 350),
(20, 'Hyderabad', 3, '13:00:00', NULL, 750);

DELIMITER //

CREATE PROCEDURE sp_TrainAvailability(
    IN from_station VARCHAR(50),
    IN to_station VARCHAR(50),
    IN journey_date DATE
)
BEGIN
    DECLARE day_of_week VARCHAR(10);

    -- Get the day name from the journey date (e.g., 'Monday')
    SET day_of_week = DAYNAME(journey_date);

    SELECT 
        t.TrainID, 
        t.TrainName, 
        ts.ScheduleID,
        from_stop.DepartureTime, 
        to_stop.ArrivalTime, 
        ts.RunningDays,
        from_stop.StationName AS FromStation,
        from_stop.DepartureTime AS FromDeparture,
        to_stop.StationName AS ToStation,
        to_stop.ArrivalTime AS ToArrival
    FROM Trains t
    JOIN TrainSchedule ts ON t.TrainID = ts.TrainID
    JOIN TrainStops from_stop ON ts.ScheduleID = from_stop.ScheduleID AND from_stop.StationName = from_station
    JOIN TrainStops to_stop ON ts.ScheduleID = to_stop.ScheduleID AND to_stop.StationName = to_station
    WHERE from_stop.StopNumber < to_stop.StopNumber;
END //

DELIMITER ;
select * from trainstops;

-- USER INTERACTION EXAMPLES

CALL sp_TrainAvailability('Delhi', 'Lucknow', '2025-04-14');

select * from coaches;

select * from ewallet;
select * from tickets;
select * from cancellation;
select * from trainstops;
select * from passengers;
select * from coaches;
select * from trains;
select * from transactions;
select * from seats;
show tables;

CALL sp_BookTicket1(
    1,           -- UserID
    1,                      -- TrainID
    (SELECT ScheduleID FROM TrainSchedule WHERE TrainID = 1),
    'Delhi',                -- FromStation
    'Patna',                -- ToStation
    '2025-04-14',           -- JourneyDate
    '1A',                   -- CoachType
    'Adi',          -- Passenger Name
    19,                     -- Age
    'M',                    -- Gender
    'wallet',               -- PaymentMethod (no PaymentID required for wallet)
    NULL,                   -- PaymentID
    @pnr,                   -- OUT: PNR
    @ticket_id              -- OUT: TicketID
);

SET @refund_amt = 0.00;
SET @status = '';

SET SQL_SAFE_UPDATES = 0;

desc seats;

CALL sp_CancelTicket(
    8,             -- TicketID
    1,           -- UserID
    'wallet',               -- RefundTo: 'wallet' or 'original_payment'
    @refund_amt,            -- OUT: RefundAmount
    @status                 -- OUT: Status
);
SELECT @refund_amt AS RefundAmount, @status AS RefundStatus;

-- Declare variables to capture output
SET @RefundAmount = 0;
SET @Status = '';

-- Call the cancellation procedure
CALL sp_CancelTicket(5, 1, 'wallet', @RefundAmount, @Status);

-- Check the result
SELECT @RefundAmount AS RefundAmount, @Status AS StatusMessage;


DELIMITER $$

CREATE PROCEDURE sp_PopulateSeatsForDate(IN p_JourneyDate DATE)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_CoachID INT;
    DECLARE v_TrainID INT;
    DECLARE v_TotalSeats INT;
    DECLARE v_ScheduleID INT;
    DECLARE v_SeatIndex INT;

    DECLARE cur CURSOR FOR
        SELECT CoachID, TrainID, TotalSeats FROM Coaches;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO v_CoachID, v_TrainID, v_TotalSeats;
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- For each CoachID, find all its Schedules
        SET v_ScheduleID = NULL;
        SELECT ScheduleID INTO v_ScheduleID
        FROM TrainSchedule
        WHERE TrainID = v_TrainID
        LIMIT 1;

        SET v_SeatIndex = 1;
        WHILE v_SeatIndex <= v_TotalSeats DO
            INSERT IGNORE INTO Seats (CoachID, SeatNumber, IsAvailable, JourneyDate, ScheduleID)
            VALUES (v_CoachID, CONCAT('S', v_SeatIndex), TRUE, p_JourneyDate, v_ScheduleID);
            SET v_SeatIndex = v_SeatIndex + 1;
        END WHILE;

    END LOOP;

    CLOSE cur;
END$$

DELIMITER ;

CALL sp_PopulateSeatsForDate('2025-04-14');
CALL sp_PopulateSeatsForDate('2025-04-15');

SELECT * FROM Seats WHERE JourneyDate = '2025-04-14' ORDER BY CoachID, SeatNumber;

select * from tickets;

CALL sp_ViewUserBookings(1, 'all', NULL, NULL);
