-- drop then create the database (needs admin rights)
DROP DATABASE IF EXISTS identity;
CREATE DATABASE identity;
USE identity;


-- database schema
CREATE TABLE identity.Users (
    id         BIGINT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(255) NOT NULL,
    last_name  VARCHAR(255) NOT NULL,
    username   VARCHAR(255) NOT NULL UNIQUE,
    email      VARCHAR(255) NOT NULL UNIQUE,
    settings   JSON CHECK (JSON_VALID(settings)),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    INDEX idx_name (first_name, last_name),
    INDEX idx_deleted_at (deleted_at)
);

CREATE TABLE identity.Credentials (
    user_id       BIGINT                                                         NOT NULL REFERENCES identity.Users (id),
    provider      ENUM ('password', 'google', 'linkedin', 'facebook', 'twitter') NOT NULL COMMENT 'the used provider',
    provider_id   VARCHAR(255)                                                   NOT NULL COMMENT 'the user id from the provider, in case of password, stores the hashed password with the salt',
    provider_data JSON CHECK (JSON_VALID(provider_data)),
    used_last     TIMESTAMP,
    used_count    INT,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'for password change mostly',
    PRIMARY KEY (user_id, provider, provider_id)
);

CREATE TABLE identity.PasswordResets (
    id           BIGINT PRIMARY KEY AUTO_INCREMENT,
    email        VARCHAR(255) NOT NULL,
    token        VARCHAR(255) NOT NULL COMMENT 'the key sent by email to allow to change the password without being logged',
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expire_at    TIMESTAMP,
    used_at      TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_token (token)
);

CREATE TABLE identity.Devices (
    id         BIGINT PRIMARY KEY AUTO_INCREMENT,
    sid        CHAR(36)     NOT NULL UNIQUE COMMENT 'a unique id stored in the browser to track it when not logged',
    user_agent VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'first time this device is seen'
) COMMENT 'a device is a browser tagged by a random id in its session';

CREATE TABLE identity.UserDevices (
    user_id     BIGINT NOT NULL REFERENCES identity.Users (id),
    device_id   BIGINT NOT NULL REFERENCES identity.Devices (id),
    linked_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'on login',
    unlinked_at TIMESTAMP COMMENT 'on logout',
    PRIMARY KEY (user_id, device_id)
) COMMENT 'created on user login to know which users are using which devices';

CREATE TABLE identity.TrustedDevices (
    user_id    BIGINT NOT NULL REFERENCES identity.Users (id),
    device_id  BIGINT NOT NULL REFERENCES identity.Devices (id),
    name       VARCHAR(255),
    kind       ENUM ('desktop', 'tablet', 'phone'),
    `usage`    ENUM ('perso', 'pro'),
    used_last  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    PRIMARY KEY (user_id, device_id),
    INDEX idx_deleted_at (deleted_at)
) COMMENT 'users can add a device to their trusted ones, so they will have longer session and less security validations';

CREATE TABLE identity.AuthLogs (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id     BIGINT REFERENCES identity.Users (id),
    email       VARCHAR(255),
    event       ENUM ('signup', 'login_success', 'login_failure', 'password_reset_asked', 'password_reset_used') NOT NULL,
    ip          VARCHAR(45)                                                                                      NOT NULL,
    ip_location POINT,
    user_agent  VARCHAR(255)                                                                                     NOT NULL,
    device_id   BIGINT                                                                                           NOT NULL REFERENCES identity.Devices (id),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- database data
INSERT INTO identity.Users (id, first_name, last_name, username, email, settings)
VALUES (1, 'John', 'Doe', 'johndoe', 'johndoe@example.com', '{"theme": "dark", "language": "en"}'),
       (2, 'Jane', 'Doe', 'janedoe', 'janedoe@example.com', '{"theme": "light", "language": "en"}'),
       (3, 'James', 'Bond', 'jamesbond', 'james.bond@mi6.co.uk', '{"theme": "dark", "language": "en"}'),
       (4, 'Bruce', 'Wayne', 'brucewayne', 'bruce.wayne@wayneenterprises.com', '{"theme": "dark", "language": "en"}'),
       (5, 'Clark', 'Kent', 'clarkkent', 'clark.kent@dailyplanet.com', '{"theme": "light", "language": "en"}'),
       (6, 'Diana', 'Prince', 'dianaprince', 'diana.prince@themyscira.gov', '{"theme": "light", "language": "en"}'),
       (7, 'Peter', 'Parker', 'peterparker', 'peter.parker@dailybugle.com', '{"theme": "light", "language": "en"}'),
       (8, 'Tony', 'Stark', 'tonystark', 'tony.stark@starkindustries.com', '{"theme": "dark", "language": "en"}'),
       (9, 'Natasha', 'Romanoff', 'natasharomanoff', 'natasha.romanoff@shield.gov', '{"theme": "dark", "language": "ru"}'),
       (10, 'Steve', 'Rogers', 'steverogers', 'steve.rogers@avengers.com', '{"theme": "light", "language": "en"}'),
       (11, 'Bruce', 'Banner', 'brucebanner', 'bruce.banner@avengers.com', '{"theme": "dark", "language": "en"}'),
       (12, 'Wanda', 'Maximoff', 'wandamaximoff', 'wanda.maximoff@avengers.com', '{"theme": "dark", "language": "en"}'),
       (13, 'Harry', 'Potter', 'harrypotter', 'harry.potter@hogwarts.ac.uk', '{"theme": "light", "language": "en"}'),
       (14, 'Hermione', 'Granger', 'hermionegranger', 'hermione.granger@hogwarts.ac.uk', '{"theme": "light", "language": "en"}'),
       (15, 'Ron', 'Weasley', 'ronweasley', 'ron.weasley@hogwarts.ac.uk', '{"theme": "light", "language": "en"}'),
       (16, 'Albus', 'Dumbledore', 'albusdumbledore', 'albus.dumbledore@hogwarts.ac.uk', '{"theme": "dark", "language": "en"}'),
       (17, 'Severus', 'Snape', 'severussnape', 'severus.snape@hogwarts.ac.uk', '{"theme": "dark", "language": "en"}'),
       (18, 'Frodo', 'Baggins', 'frodobaggins', 'frodo.baggins@shire.me', '{"theme": "light", "language": "en"}'),
       (19, 'Samwise', 'Gamgee', 'samwisegamgee', 'samwise.gamgee@shire.me', '{"theme": "light", "language": "en"}'),
       (20, 'Gandalf', 'the Grey', 'gandalfthegrey', 'gandalf@middleearth.me', '{"theme": "dark", "language": "en"}'),
       (21, 'Aragorn', 'Elessar', 'aragornelessar', 'aragorn@middleearth.me', '{"theme": "dark", "language": "en"}'),
       (22, 'Legolas', 'Greenleaf', 'legolasgreenleaf', 'legolas@woodlandrealm.me', '{"theme": "light", "language": "en"}'),
       (23, 'Gimli', 'Son of Glóin', 'gimlisonofgloin', 'gimli@lonelymountain.me', '{"theme": "dark", "language": "en"}'),
       (24, 'Sherlock', 'Holmes', 'sherlockholmes', 'sherlock.holmes@bakerstreet.com', '{"theme": "dark", "language": "en"}'),
       (25, 'John', 'Watson', 'johnwatson', 'john.watson@bakerstreet.com', '{"theme": "light", "language": "en"}'),
       (26, 'Bilbo', 'Baggins', 'bilbobaggins', 'bilbo.baggins@shire.me', '{"theme": "light", "language": "en"}'),
       (27, 'Tony', 'Montana', 'tonymontana', 'tony.montana@scarface.com', '{"theme": "dark", "language": "en"}'),
       (28, 'Michael', 'Corleone', 'michaelcorleone', 'michael.corleone@corleone.com', '{"theme": "dark", "language": "en"}'),
       (29, 'Vito', 'Corleone', 'vitocorleone', 'vito.corleone@corleone.com', '{"theme": "dark", "language": "it"}'),
       (30, 'Ellen', 'Ripley', 'ellenripley', 'ellen.ripley@weylandyutani.com', '{"theme": "dark", "language": "en"}'),
       (31, 'Sarah', 'Connor', 'sarahconnor', 'sarah.connor@skynet.com', '{"theme": "dark", "language": "en"}'),
       (32, 'Neo', 'Anderson', 'neoanderson', 'neo.anderson@matrix.com', '{"theme": "dark", "language": "en"}'),
       (33, 'Trinity', '', 'trinity', 'trinity@matrix.com', '{"theme": "dark", "language": "en"}'),
       (34, 'Morpheus', '', 'morpheus', 'morpheus@matrix.com', '{"theme": "dark", "language": "en"}'),
       (35, 'Ethan', 'Hunt', 'ethanhunt', 'ethan.hunt@imf.gov', '{"theme": "dark", "language": "en"}'),
       (36, 'Indiana', 'Jones', 'indianajones', 'indiana.jones@archeology.com', '{"theme": "dark", "language": "en"}'),
       (37, 'Han', 'Solo', 'hansolo', 'han.solo@rebellion.com', '{"theme": "dark", "language": "en"}'),
       (38, 'Luke', 'Skywalker', 'lukeskywalker', 'luke.skywalker@rebellion.com', '{"theme": "light", "language": "en"}'),
       (39, 'Leia', 'Organa', 'leiaorgana', 'leia.organa@rebellion.com', '{"theme": "light", "language": "en"}'),
       (40, 'Yoda', '', 'yoda', 'yoda@jediorder.com', '{"theme": "dark", "language": "en"}'),
       (41, 'Obi-Wan', 'Kenobi', 'obiwankenobi', 'obi-wan.kenobi@jediorder.com', '{"theme": "light", "language": "en"}'),
       (42, 'Anakin', 'Skywalker', 'anakinskywalker', 'anakin.skywalker@jediorder.com', '{"theme": "dark", "language": "en"}'),
       (43, 'Darth', 'Vader', 'darthvader', 'darth.vader@empire.com', '{"theme": "dark", "language": "en"}'),
       (44, 'Kylo', 'Ren', 'kyloren', 'kylo.ren@firstorder.com', '{"theme": "dark", "language": "en"}'),
       (45, 'Rey', '', 'rey', 'rey@resistance.com', '{"theme": "light", "language": "en"}'),
       (46, 'Finn', '', 'finn', 'finn@resistance.com', '{"theme": "light", "language": "en"}'),
       (47, 'Poe', 'Dameron', 'poedameron', 'poe.dameron@resistance.com', '{"theme": "light", "language": "en"}'),
       (48, 'Arthur', 'Dent', 'arthurdent', 'arthur.dent@hitchhikersguide.com', '{"theme": "light", "language": "en"}'),
       (49, 'Zaphod', 'Beeblebrox', 'zaphodbeeblebrox', 'zaphod.beeblebrox@hitchhikersguide.com', '{"theme": "dark", "language": "en"}'),
       (50, 'Ford', 'Prefect', 'fordprefect', 'ford.prefect@hitchhikersguide.com', '{"theme": "light", "language": "en"}'),
       (51, 'Marvin', 'the Paranoid Android', 'marvinandroid', 'marvin@hitchhikersguide.com', '{"theme": "dark", "language": "en"}'),
       (52, 'Arthur', 'Morgan', 'arthurmorgan', 'arthur.morgan@reddead.com', '{"theme": "dark", "language": "en"}'),
       (53, 'John', 'Marston', 'johnmarston', 'john.marston@reddead.com', '{"theme": "dark", "language": "en"}'),
       (54, 'Tommy', 'Vercetti', 'tommyvercetti', 'tommy.vercetti@vicecity.com', '{"theme": "dark", "language": "en"}'),
       (55, 'Carl', 'Johnson', 'carljohnson', 'carl.johnson@sweet.com', '{"theme": "dark", "language": "en"}'),
       (56, 'Lara', 'Croft', 'laracroft', 'lara.croft@tombraider.com', '{"theme": "dark", "language": "en"}'),
       (57, 'Nathan', 'Drake', 'nathandrake', 'nathan.drake@uncharted.com', '{"theme": "light", "language": "en"}'),
       (58, 'Kratos', '', 'kratos', 'kratos@godofwar.com', '{"theme": "dark", "language": "en"}'),
       (59, 'Atreus', '', 'atreus', 'atreus@godofwar.com', '{"theme": "light", "language": "en"}'),
       (60, 'Geralt', 'of Rivia', 'geraltofrivia', 'geralt@witcher.com', '{"theme": "dark", "language": "en"}'),
       (61, 'Ciri', '', 'ciri', 'ciri@witcher.com', '{"theme": "light", "language": "en"}'),
       (62, 'Yennefer', 'of Vengerberg', 'yennefer', 'yennefer@witcher.com', '{"theme": "dark", "language": "en"}'),
       (63, 'Batman', '', 'batman', 'batman@gotham.com', '{"theme": "dark", "language": "en"}'),
       (64, 'Superman', '', 'superman', 'superman@metropolis.com', '{"theme": "light", "language": "en"}'),
       (65, 'Wolverine', '', 'wolverine', 'wolverine@xmen.com', '{"theme": "dark", "language": "en"}'),
       (66, 'Charles', 'Xavier', 'charlesxavier', 'charles.xavier@xmen.com', '{"theme": "light", "language": "en"}'),
       (67, 'Logan', '', 'logan', 'logan@xmen.com', '{"theme": "dark", "language": "en"}'),
       (68, 'Jean', 'Grey', 'jeangrey', 'jean.grey@xmen.com', '{"theme": "light", "language": "en"}'),
       (69, 'Magneto', '', 'magneto', 'magneto@brotherhood.com', '{"theme": "dark", "language": "en"}'),
       (70, 'Deadpool', '', 'deadpool', 'deadpool@xmen.com', '{"theme": "dark", "language": "en"}'),
       (71, 'Thanos', '', 'thanos', 'thanos@titan.com', '{"theme": "dark", "language": "en"}'),
       (72, 'Rocket', 'Raccoon', 'rocketraccoon', 'rocket.raccoon@guardians.com', '{"theme": "light", "language": "en"}'),
       (73, 'Groot', '', 'groot', 'groot@guardians.com', '{"theme": "light", "language": "en"}'),
       (74, 'Gamora', '', 'gamora', 'gamora@guardians.com', '{"theme": "dark", "language": "en"}'),
       (75, 'Star-Lord', '', 'starlord', 'star-lord@guardians.com', '{"theme": "light", "language": "en"}'),
       (76, 'Drax', 'the Destroyer', 'drax', 'drax@guardians.com', '{"theme": "dark", "language": "en"}'),
       (77, 'Sheldon', 'Cooper', 'sheldoncooper', 'sheldon.cooper@caltech.edu', '{"theme": "light", "language": "en"}'),
       (78, 'Leonard', 'Hofstadter', 'leonardhofstadter', 'leonard.hofstadter@caltech.edu', '{"theme": "light", "language": "en"}'),
       (79, 'Penny', '', 'penny', 'penny@thecheesecakefactory.com', '{"theme": "light", "language": "en"}'),
       (80, 'Howard', 'Wolowitz', 'howardwolowitz', 'howard.wolowitz@caltech.edu', '{"theme": "light", "language": "en"}'),
       (81, 'Raj', 'Koothrappali', 'rajkoothrappali', 'raj.koothrappali@caltech.edu', '{"theme": "light", "language": "en"}'),
       (82, 'Jesse', 'Pinkman', 'jessepinkman', 'jesse.pinkman@lospolloshermanos.com', '{"theme": "dark", "language": "en"}'),
       (83, 'Walter', 'White', 'walterwhite', 'walter.white@lospolloshermanos.com', '{"theme": "dark", "language": "en"}'),
       (84, 'Saul', 'Goodman', 'saulgoodman', 'saul.goodman@law.com', '{"theme": "dark", "language": "en"}'),
       (85, 'Homer', 'Simpson', 'homersimpson', 'homer.simpson@thesimpsons.com', '{"theme": "light", "language": "en"}'),
       (86, 'Marge', 'Simpson', 'margesimpson', 'marge.simpson@thesimpsons.com', '{"theme": "light", "language": "en"}'),
       (87, 'Bart', 'Simpson', 'bartsimpson', 'bart.simpson@thesimpsons.com', '{"theme": "light", "language": "en"}'),
       (88, 'Lisa', 'Simpson', 'lisasimpson', 'lisa.simpson@thesimpsons.com', '{"theme": "light", "language": "en"}'),
       (89, 'Maggie', 'Simpson', 'maggiesimpson', 'maggie.simpson@thesimpsons.com', '{"theme": "light", "language": "en"}'),
       (90, 'Rick', 'Sanchez', 'ricksanchez', 'rick.sanchez@rickandmorty.com', '{"theme": "dark", "language": "en"}'),
       (91, 'Morty', 'Smith', 'mortysmith', 'morty.smith@rickandmorty.com', '{"theme": "light", "language": "en"}'),
       (92, 'Jerry', 'Smith', 'jerrysmith', 'jerry.smith@rickandmorty.com', '{"theme": "light", "language": "en"}'),
       (93, 'Summer', 'Smith', 'summersmith', 'summer.smith@rickandmorty.com', '{"theme": "light", "language": "en"}'),
       (94, 'Beth', 'Smith', 'bethsmith', 'beth.smith@rickandmorty.com', '{"theme": "light", "language": "en"}'),
       (95, 'Fry', 'Phillip J.', 'fry', 'fry@planetexpress.com', '{"theme": "light", "language": "en"}'),
       (96, 'Bender', 'Rodriguez', 'bender', 'bender@planetexpress.com', '{"theme": "dark", "language": "en"}'),
       (97, 'Leela', 'Turanga', 'leela', 'leela@planetexpress.com', '{"theme": "light", "language": "en"}'),
       (98, 'Zoidberg', 'John A.', 'zoidberg', 'zoidberg@planetexpress.com', '{"theme": "light", "language": "en"}'),
       (99, 'Professor', 'Farnsworth', 'farnsworth', 'farnsworth@planetexpress.com', '{"theme": "dark", "language": "en"}'),
       (100, 'Hermes', 'Conrad', 'hermes', 'hermes@planetexpress.com', '{"theme": "light", "language": "en"}'),
       (101, 'Amy', 'Wong', 'amy', 'amy@planetexpress.com', '{"theme": "light", "language": "en"}'),
       (102, 'SpongeBob', 'SquarePants', 'spongebob', 'spongebob@bikinibottom.com', '{"theme": "light", "language": "en"}'),
       (103, 'Patrick', 'Star', 'patrickstar', 'patrick@bikinibottom.com', '{"theme": "light", "language": "en"}'),
       (104, 'Squidward', 'Tentacles', 'squidward', 'squidward@bikinibottom.com', '{"theme": "dark", "language": "en"}'),
       (105, 'Mr.', 'Krabs', 'mrkrabs', 'mr.krabs@bikinibottom.com', '{"theme": "dark", "language": "en"}'),
       (106, 'Plankton', 'Sheldon J.', 'plankton', 'plankton@bikinibottom.com', '{"theme": "dark", "language": "en"}'),
       (107, 'Sandy', 'Cheeks', 'sandycheeks', 'sandy.cheeks@bikinibottom.com', '{"theme": "light", "language": "en"}'),
       (108, 'Michael', 'Scott', 'michaelscott', 'michael.scott@dundermifflin.com', '{"theme": "light", "language": "en"}'),
       (109, 'Dwight', 'Schrute', 'dwightschrute', 'dwight.schrute@dundermifflin.com', '{"theme": "dark", "language": "en"}'),
       (110, 'Jim', 'Halpert', 'jimhalpert', 'jim.halpert@dundermifflin.com', '{"theme": "light", "language": "en"}'),
       (111, 'Pam', 'Beesly', 'pambeesly', 'pam.beesly@dundermifflin.com', '{"theme": "light", "language": "en"}'),
       (112, 'Stanley', 'Hudson', 'stanleyhudson', 'stanley.hudson@dundermifflin.com', '{"theme": "dark", "language": "en"}'),
       (113, 'Kevin', 'Malone', 'kevinmalone', 'kevin.malone@dundermifflin.com', '{"theme": "light", "language": "en"}'),
       (114, 'Oscar', 'Martinez', 'oscarmartinez', 'oscar.martinez@dundermifflin.com', '{"theme": "light", "language": "en"}'),
       (115, 'Phyllis', 'Vance', 'phyllisvance', 'phyllis.vance@dundermifflin.com', '{"theme": "light", "language": "en"}'),
       (116, 'Angela', 'Martin', 'angelamartin', 'angela.martin@dundermifflin.com', '{"theme": "dark", "language": "en"}'),
       (117, 'Andy', 'Bernard', 'andybernard', 'andy.bernard@dundermifflin.com', '{"theme": "light", "language": "en"}'),
       (118, 'Creed', 'Bratton', 'creedbratton', 'creed.bratton@dundermifflin.com', '{"theme": "dark", "language": "en"}'),
       (119, 'Meredith', 'Palmer', 'meredithpalmer', 'meredith.palmer@dundermifflin.com', '{"theme": "dark", "language": "en"}'),
       (120, 'Ryan', 'Howard', 'ryanhoward', 'ryan.howard@dundermifflin.com', '{"theme": "dark", "language": "en"}'),
       (121, 'Kelly', 'Kapoor', 'kellykapoor', 'kelly.kapoor@dundermifflin.com', '{"theme": "light", "language": "en"}'),
       (122, 'Toby', 'Flenderson', 'tobyflenderson', 'toby.flenderson@dundermifflin.com', '{"theme": "dark", "language": "en"}'),
       (123, 'Daryl', 'Philbin', 'darylphilbin', 'daryl.philbin@dundermifflin.com', '{"theme": "light", "language": "en"}');

INSERT INTO identity.Credentials (user_id, provider, provider_id, provider_data, used_last, used_count)
VALUES (1, 'password', '$2a$10$IphbkzyF2NZlEvvFXrQw5eELqiTV3U.u7Hx4QMCA0yhpubUsUMNnW', '{"algorithm": "bcrypt", "salt": "a8f5f167f44f4964e6c998dee827110c"}', CURRENT_TIMESTAMP, 5),
       (1, 'twitter', '192837465', '{"id_str": "192837465", "name": "John Doe", "screen_name": "johndoe", "location": "Metropolis, USA", "profile_image_url_https": "https://pbs.twimg.com/profile_images/123456789/johndoe_400x400.jpg", "email": "johndoe@example.com", "verified": true}', CURRENT_TIMESTAMP, 15),
       (2, 'password', '$2a$10$PEK5WPg5qxKOmntN8sT4bOzOf/omzk0.CVNJAKp2MBdS4o2Mpgq2G', '{"algorithm": "bcrypt", "salt": "7b9c1c8d5b3e469fb6d4e98b9578efc5"}', CURRENT_TIMESTAMP, 4),
       (3, 'password', '$2a$10$Fot3cix5fRC7HMqXN7jTvuqfsVVCM5Wp5G2RSeVkf1U1NdkfBG6Jy', '{"algorithm": "bcrypt", "salt": "1d6f82c8b3494fda8b183a8e47d66d14"}', CURRENT_TIMESTAMP, 7),
       (4, 'google', '108947621839247391020', '{"sub": "108947621839247391020", "name": "Bruce Wayne", "given_name": "Bruce", "family_name": "Wayne", "picture": "https://lh3.googleusercontent.com/a-/AOh14Gg-batmanprofilepic/AAAAAAAAAAA/photo.jpg", "email": "bruce.wayne@wayneenterprises.com", "email_verified": true, "locale": "en"}', CURRENT_TIMESTAMP, 12),
       (5, 'facebook', '10293847561234567', '{"id": "10293847561234567", "name": "Clark Kent", "first_name": "Clark", "last_name": "Kent", "email": "clark.kent@dailyplanet.com", "picture": {"data": {"url": "https://graph.facebook.com/10293847561234567/picture?type=large"}}, "locale": "en_US"}', CURRENT_TIMESTAMP, 3),
       (6, 'linkedin', 'diana-prince-123456789', '{"id": "diana-prince-123456789", "localizedFirstName": "Diana", "localizedLastName": "Prince", "profilePicture": {"displayImage": "https://media-exp1.licdn.com/dms/image/C4E03AQFZ8DqeOgx5YA/profile-displayphoto-shrink_200_200/0/1517436071201?e=1624320000&v=beta&t=LQyE8g4BLwNxYc6GZJ9Nz4u8MJE1z3kJDcF6Gf9OMwY"}, "emailAddress": "diana.prince@themyscira.gov"}', CURRENT_TIMESTAMP, 6),
       (7, 'password', '$2a$10$kf2vdK9OY8mnTiT5VQYK2u80PhxTIJmKc1y/9UUphrI2vPUougX/W', '{"algorithm": "bcrypt", "salt": "4c6e2bbad3f74a4cbf50e08f7e9a2951"}', CURRENT_TIMESTAMP, 9),
       (8, 'twitter', '25073877', '{"id_str": "25073877", "name": "Tony Stark", "screen_name": "IronMan", "location": "Stark Tower, NYC", "profile_image_url_https": "https://pbs.twimg.com/profile_images/875400512/tonystark_400x400.jpg", "email": "tony.stark@starkindustries.com", "verified": true}', CURRENT_TIMESTAMP, 20),
       (9, 'password', '$2a$10$mXyJ3ERqiZFnDUzWoe/BqOTji0VSRAPHu5CHmQCnXcNvjB3dAagne', '{"algorithm": "bcrypt", "salt": "9f8e7c9d3b414f5e94b4670b8e5a2b19"}', CURRENT_TIMESTAMP, 11),
       (10, 'password', '$2a$10$l5c6QaTo/dIJOcUCoooWaOJrD7IvKH52PNCcGxONn5rPD5JLa/ZsC', '{"algorithm": "bcrypt", "salt": "e3c0d5f6a1f84f45b6c3e8e17d8c925b"}', CURRENT_TIMESTAMP, 8),
       (11, 'google', '116834789476231098765', '{"sub": "116834789476231098765", "name": "Bruce Banner", "given_name": "Bruce", "family_name": "Banner", "picture": "https://lh3.googleusercontent.com/a-/AOh14Gg-hulkprofilepic/AAAAAAAAAAA/photo.jpg", "email": "bruce.banner@avengers.com", "email_verified": true, "locale": "en"}', CURRENT_TIMESTAMP, 14),
       (12, 'password', '$2a$10$kVnyLvCybOAxcB7zF/g.W.628fux.jbNoCN8tfIZnt8Ct9/liMer.', '{"algorithm": "bcrypt", "salt": "b7d9e4c5a6f34d88b6c3f1a7c0e2b839"}', CURRENT_TIMESTAMP, 6),
       (13, 'facebook', '20394857618234567', '{"id": "20394857618234567", "name": "Harry Potter", "first_name": "Harry", "last_name": "Potter", "email": "harry.potter@hogwarts.ac.uk", "picture": {"data": {"url": "https://graph.facebook.com/20394857618234567/picture?type=large"}}, "locale": "en_GB"}', CURRENT_TIMESTAMP, 2),
       (14, 'linkedin', 'hermione-granger-234567890', '{"id": "hermione-granger-234567890", "localizedFirstName": "Hermione", "localizedLastName": "Granger", "profilePicture": {"displayImage": "https://media-exp1.licdn.com/dms/image/C4E03AQGxZSDdfx3Y5A/profile-displayphoto-shrink_200_200/0/1517535071201?e=1624320000&v=beta&t=KJ2F8w5IZKx5BsAUbjf8_YD3X9O9s3kFDZpD2aZ3PfM"}, "emailAddress": "hermione.granger@hogwarts.ac.uk"}', CURRENT_TIMESTAMP, 5),
       (15, 'twitter', '33421598', '{"id_str": "33421598", "name": "Ron Weasley", "screen_name": "TheWeasel", "location": "The Burrow, Ottery St Catchpole", "profile_image_url_https": "https://pbs.twimg.com/profile_images/378800000/ronweasley_400x400.jpg", "email": "ron.weasley@hogwarts.ac.uk", "verified": true}', CURRENT_TIMESTAMP, 4),
       (16, 'password', '$2a$10$pLnLSBoC1Ucrkh9QQzSlQO9BS5oeLqiZR2tymbuoZRED430p7euwG', '{"algorithm": "bcrypt", "salt": "c3a7e2d8f1b74b56b9c8f4d9e6a7c235"}', CURRENT_TIMESTAMP, 10),
       (17, 'google', '109865432198765432109', '{"sub": "109865432198765432109", "name": "Severus Snape", "given_name": "Severus", "family_name": "Snape", "picture": "https://lh3.googleusercontent.com/a-/AOh14Gg-snapepic/AAAAAAAAAAA/photo.jpg", "email": "severus.snape@hogwarts.ac.uk", "email_verified": true, "locale": "en"}', CURRENT_TIMESTAMP, 13),
       (18, 'password', '$2a$10$OpNiFmlD2oPCLMSgxvCnDev1ROrahuH4S.nqbvX3VFSnkxWuTHKIe', '{"algorithm": "bcrypt", "salt": "5a6c8f9d2e3b4f17c6e7b9f8d5a2c3e4"}', CURRENT_TIMESTAMP, 6),
       (19, 'password', '$2a$10$rqge0CSMuq1b2lluLF5EKO7eOP19YX0qn2Ikmd/OKN.sMLIqPCE5u', '{"algorithm": "bcrypt", "salt": "2f3e5d6c7b4a1d8e9c2f7b5e6a4d9c13"}', CURRENT_TIMESTAMP, 7),
       (20, 'linkedin', 'gandalf-grey-345678901', '{"id": "gandalf-grey-345678901", "localizedFirstName": "Gandalf", "localizedLastName": "the Grey", "profilePicture": {"displayImage": "https://media-exp1.licdn.com/dms/image/C4E03AQFZ8DqeOgx5YA/profile-displayphoto-shrink_200_200/0/1517436071201?e=1624320000&v=beta&t=LQyE8g4BLwNxYc6GZJ9Nz4u8MJE1z3kJDcF6Gf9OMwY"}, "emailAddress": "gandalf@middleearth.me"}', CURRENT_TIMESTAMP, 9),
       (21, 'facebook', '30495876123456789', '{"id": "30495876123456789", "name": "Aragorn Elessar", "first_name": "Aragorn", "last_name": "Elessar", "email": "aragorn@middleearth.me", "picture": {"data": {"url": "https://graph.facebook.com/30495876123456789/picture?type=large"}}, "locale": "en_US"}', CURRENT_TIMESTAMP, 8),
       (22, 'password', '$2a$10$r.AQAnbsSTB6VVU2I.pF6u4/qc1Z.rHNUXnxqwxLjNyMIhHnyfuWK', '{"algorithm": "bcrypt", "salt": "3b4d6e7f5a2c1e8f9d7c3b6a4f5e9d18"}', CURRENT_TIMESTAMP, 5),
       (23, 'password', '$2a$10$Ojml6vqxh.YemFguenicBedeoJN7quOhSrk7839dSR8GGA7rjyuOe', '{"algorithm": "bcrypt", "salt": "1e2f3b4a6d7c5e9f8b3c7d6a4f2e5b19"}', CURRENT_TIMESTAMP, 4);

INSERT INTO identity.PasswordResets (email, token, requested_at, expire_at, used_at)
VALUES ('johndoe@example.com', 'a1b2c3d4e5f6g7h8i9j0', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL 1 HOUR, NULL),
       ('janedoe@example.com', 'f1e2d3c4b5a6g7h8i9j0', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL 1 HOUR, CURRENT_TIMESTAMP + INTERVAL 10 MINUTE);

INSERT INTO identity.Devices (sid, user_agent)
VALUES ('550e8400-e29b-41d4-a716-446655440000', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36'),
       ('66eebccb-8d67-4b3e-b218-8a4d24c3f5d3', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15'),
       ('123e4567-e89b-12d3-a456-426614174000', 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1'),
       ('92ef1ac7-7391-4b9b-abc7-5f1f0ec9f93b', 'Mozilla/5.0 (Linux; Android 11; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Mobile Safari/537.36'),
       ('b019fd28-7e8c-4c7d-b432-d3e2b5c74221', 'Mozilla/5.0 (iPad; CPU OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1'),
       ('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0'),
       ('21bffb99-78a1-4b92-b162-81cfd8b3bcec', 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'),
       ('77bfcc0d-98d1-4c43-88b2-f3c1e8d3f939', 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1'),
       ('c9bde7a0-6f79-4a88-b2cb-274abf1d4a62', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36'),
       ('b43ae61a-4f34-445d-b0d9-6eb8c5e7b13b', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:90.0) Gecko/20100101 Firefox/90.0');

INSERT INTO identity.UserDevices (user_id, device_id, linked_at)
VALUES (1, 1, CURRENT_TIMESTAMP),
       (1, 2, CURRENT_TIMESTAMP),
       (1, 3, CURRENT_TIMESTAMP),
       (2, 3, CURRENT_TIMESTAMP),
       (3, 4, CURRENT_TIMESTAMP),
       (4, 5, CURRENT_TIMESTAMP),
       (5, 6, CURRENT_TIMESTAMP),
       (6, 7, CURRENT_TIMESTAMP),
       (7, 8, CURRENT_TIMESTAMP),
       (8, 9, CURRENT_TIMESTAMP),
       (9, 10, CURRENT_TIMESTAMP);

INSERT INTO identity.TrustedDevices (user_id, device_id, name, kind, `usage`, used_last, created_at)
VALUES (1, 1, 'John\'s Windows PC', 'desktop', 'perso', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
       (1, 2, 'John\'s MacBook Pro', 'desktop', 'pro', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
       (3, 4, 'James\' Android Phone', 'phone', 'perso', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
       (4, 5, 'Bruce\'s iPad', 'tablet', 'pro', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO identity.AuthLogs (user_id, email, event, ip, ip_location, user_agent, device_id, created_at)
VALUES (1, 'johndoe@example.com', 'signup', '192.168.1.10', ST_GeomFromText('POINT(48.8588443 2.2943506)'), 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36', 1, CURRENT_TIMESTAMP - INTERVAL 30 DAY),
       (2, 'janedoe@example.com', 'signup', '172.16.0.15', ST_GeomFromText('POINT(51.507351 -0.127758)'), 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1', 3, CURRENT_TIMESTAMP - INTERVAL 30 DAY),
       (1, 'johndoe@example.com', 'login_success', '192.168.1.10', NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36', 1, CURRENT_TIMESTAMP - INTERVAL 29 DAY),
       (2, 'janedoe@example.com', 'login_success', '172.16.0.15', NULL, 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1', 3, CURRENT_TIMESTAMP - INTERVAL 29 DAY),
       (1, 'johndoe@example.com', 'login_failure', '192.168.1.11', NULL, 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15', 2, CURRENT_TIMESTAMP - INTERVAL 20 DAY),
       (1, 'johndoe@example.com', 'login_success', '192.168.1.11', NULL, 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15', 2, CURRENT_TIMESTAMP - INTERVAL 20 DAY),
       (2, 'janedoe@example.com', 'login_failure', '172.16.0.16', NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36', 1, CURRENT_TIMESTAMP - INTERVAL 20 DAY),
       (2, 'janedoe@example.com', 'login_success', '172.16.0.16', NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36', 1, CURRENT_TIMESTAMP - INTERVAL 20 DAY),
       (1, 'johndoe@example.com', 'login_failure', '192.168.1.12', NULL, 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1', 3, CURRENT_TIMESTAMP - INTERVAL 10 DAY),
       (1, 'johndoe@example.com', 'login_success', '192.168.1.12', NULL, 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1', 3, CURRENT_TIMESTAMP - INTERVAL 10 DAY),
       (2, 'janedoe@example.com', 'password_reset_asked', '172.16.0.15', NULL, 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1', 3, CURRENT_TIMESTAMP - INTERVAL 10 DAY),
       (2, 'janedoe@example.com', 'password_reset_used', '172.16.0.15', NULL, 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1', 3, CURRENT_TIMESTAMP - INTERVAL 9 DAY),
       (1, 'johndoe@example.com', 'password_reset_asked', '192.168.1.10', NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36', 1, CURRENT_TIMESTAMP - INTERVAL 5 DAY),
       (2, 'janedoe@example.com', 'login_success', '172.16.0.16', NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36', 1, CURRENT_TIMESTAMP - INTERVAL 5 DAY),
       (1, 'johndoe@example.com', 'password_reset_used', '192.168.1.10', NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36', 1, CURRENT_TIMESTAMP - INTERVAL 4 DAY),
       (1, 'johndoe@example.com', 'login_success', '192.168.1.10', NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36', 1, CURRENT_TIMESTAMP - INTERVAL 1 DAY),
       (2, 'janedoe@example.com', 'login_success', '172.16.0.15', NULL, 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1', 3, CURRENT_TIMESTAMP - INTERVAL 1 DAY);
