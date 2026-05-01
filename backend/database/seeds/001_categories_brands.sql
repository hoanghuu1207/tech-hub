-- ============================================================
-- TechShop — Seed Data: Categories, Brands, Spec Templates
-- ============================================================

-- ============================================================
-- CATEGORIES (parent → children)
-- ============================================================

-- Smartphone
INSERT INTO categories (name, slug, description, sort_order) VALUES
('Điện thoại', 'smartphone', 'Điện thoại thông minh', 1);

INSERT INTO categories (name, slug, parent_id, sort_order) VALUES
('iPhone', 'iphone', (SELECT category_id FROM categories WHERE slug = 'smartphone'), 1),
('Android Phone', 'android-phone', (SELECT category_id FROM categories WHERE slug = 'smartphone'), 2);

-- Laptop
INSERT INTO categories (name, slug, description, sort_order) VALUES
('Laptop', 'laptop', 'Máy tính xách tay', 2);

INSERT INTO categories (name, slug, parent_id, sort_order) VALUES
('MacBook', 'macbook', (SELECT category_id FROM categories WHERE slug = 'laptop'), 1),
('Windows Laptop', 'windows-laptop', (SELECT category_id FROM categories WHERE slug = 'laptop'), 2);

-- Tablet
INSERT INTO categories (name, slug, description, sort_order) VALUES
('Máy tính bảng', 'tablet', 'Máy tính bảng', 3);

-- Headphone
INSERT INTO categories (name, slug, description, sort_order) VALUES
('Tai nghe', 'headphone', 'Tai nghe các loại', 4);

INSERT INTO categories (name, slug, parent_id, sort_order) VALUES
('TWS', 'tws', (SELECT category_id FROM categories WHERE slug = 'headphone'), 1),
('Over-Ear', 'over-ear', (SELECT category_id FROM categories WHERE slug = 'headphone'), 2);

-- Smartwatch
INSERT INTO categories (name, slug, description, sort_order) VALUES
('Đồng hồ thông minh', 'smartwatch', 'Đồng hồ thông minh', 5);

-- Accessory
INSERT INTO categories (name, slug, description, sort_order) VALUES
('Phụ kiện', 'accessory', 'Phụ kiện công nghệ', 6);

INSERT INTO categories (name, slug, parent_id, sort_order) VALUES
('Cáp sạc', 'cable', (SELECT category_id FROM categories WHERE slug = 'accessory'), 1),
('Ốp lưng', 'case', (SELECT category_id FROM categories WHERE slug = 'accessory'), 2),
('Sạc', 'charger', (SELECT category_id FROM categories WHERE slug = 'accessory'), 3),
('Bàn phím', 'keyboard', (SELECT category_id FROM categories WHERE slug = 'accessory'), 4);


-- ============================================================
-- BRANDS
-- ============================================================
INSERT INTO brands (name, slug, country) VALUES
('Apple',   'apple',   'Mỹ'),
('Samsung', 'samsung', 'Hàn Quốc'),
('Xiaomi',  'xiaomi',  'Trung Quốc'),
('OPPO',    'oppo',    'Trung Quốc'),
('Vivo',    'vivo',    'Trung Quốc'),
('Dell',    'dell',    'Mỹ'),
('HP',      'hp',      'Mỹ'),
('ASUS',    'asus',    'Đài Loan'),
('Lenovo',  'lenovo',  'Trung Quốc'),
('MSI',     'msi',     'Đài Loan'),
('Sony',    'sony',    'Nhật Bản'),
('JBL',     'jbl',     'Mỹ'),
('Bose',    'bose',    'Mỹ'),
('Garmin',  'garmin',  'Mỹ'),
('Huawei',  'huawei',  'Trung Quốc'),
('Honor',   'honor',   'Trung Quốc'),
('Realme',  'realme',  'Trung Quốc'),
('Coros',   'coros',   'Mỹ'),
('Huami',   'huami',   'Trung Quốc'),
('Kieslect','kieslect','Trung Quốc'),
('Soundpeats','soundpeats','Trung Quốc'),
('Black Shark','black-shark','Trung Quốc'),
('Masstel', 'masstel', 'Việt Nam'),
('SUUNTO',  'suunto',  'Phần Lan'),
('Mibro',   'mibro',   'Trung Quốc'),
('Viettel', 'viettel', 'Việt Nam'),
('Wonlex',  'wonlex',  'Trung Quốc'),
('Marshall','marshall','Anh'),
('Anker',   'anker',   'Trung Quốc'),
('Havit',   'havit',   'Trung Quốc'),
('Edifier', 'edifier', 'Trung Quốc'),
('Baseus',  'baseus',  'Trung Quốc'),
('Shokz',   'shokz',   'Mỹ'),
('Sennheiser','sennheiser','Đức'),
('Hyperx',  'hyperx',  'Mỹ'),
('Logitech','logitech','Thụy Sĩ'),
('Aukey',   'aukey',   'Trung Quốc'),
('Beats',   'beats',   'Mỹ'),
('Nothing', 'nothing', 'Anh'),
('QCY',     'qcy',     'Trung Quốc'),
('Ugreen',  'ugreen',  'Trung Quốc'),
('Tronsmart','tronsmart','Trung Quốc'),
('AKG',     'akg',     'Áo'),
('Bowers & Wilkins','bowers-wilkins','Anh'),
('Nakamichi','nakamichi','Nhật Bản');


-- ============================================================
-- SPEC TEMPLATES: smartphone
-- ============================================================
INSERT INTO spec_templates (category_id, spec_key, display_name, data_type, unit, spec_group, is_filterable, sort_order)
SELECT c.category_id, v.spec_key, v.display_name, v.data_type, v.unit, v.spec_group, v.is_filterable, v.sort_order
FROM categories c,
(VALUES
    ('screen_size_inch',   'Kích thước màn hình', 'number',  'inch', 'Màn hình',  TRUE,  1),
    ('screen_resolution',  'Độ phân giải',        'text',    NULL,   'Màn hình',  FALSE, 2),
    ('screen_refresh_rate','Tần số quét',          'number',  'Hz',   'Màn hình',  TRUE,  3),
    ('screen_technology',  'Công nghệ màn hình',  'text',    NULL,   'Màn hình',  FALSE, 4),
    ('chipset',            'Chipset',              'text',    NULL,   'Hiệu năng', TRUE,  5),
    ('ram_gb',             'RAM',                  'number',  'GB',   'Hiệu năng', TRUE,  6),
    ('storage_gb',         'Bộ nhớ trong',         'number',  'GB',   'Hiệu năng', TRUE,  7),
    ('os',                 'Hệ điều hành',         'text',    NULL,   'Hiệu năng', TRUE,  8),
    ('camera_main_mp',     'Camera chính',         'number',  'MP',   'Camera',    TRUE,  9),
    ('camera_front_mp',    'Camera selfie',        'number',  'MP',   'Camera',    FALSE, 10),
    ('battery_mah',        'Dung lượng pin',       'number',  'mAh', 'Pin & Sạc', TRUE,  11),
    ('fast_charge_w',      'Sạc nhanh',            'number',  'W',    'Pin & Sạc', TRUE,  12),
    ('weight_g',           'Trọng lượng',          'number',  'g',    'Thiết kế',  FALSE, 13),
    ('5g',                 'Hỗ trợ 5G',            'boolean', NULL,   'Kết nối',   TRUE,  14),
    ('nfc',                'NFC',                  'boolean', NULL,   'Kết nối',   FALSE, 15)
) AS v(spec_key, display_name, data_type, unit, spec_group, is_filterable, sort_order)
WHERE c.slug = 'smartphone';


-- ============================================================
-- SPEC TEMPLATES: laptop
-- ============================================================
INSERT INTO spec_templates (category_id, spec_key, display_name, data_type, unit, spec_group, is_filterable, sort_order)
SELECT c.category_id, v.spec_key, v.display_name, v.data_type, v.unit, v.spec_group, v.is_filterable, v.sort_order
FROM categories c,
(VALUES
    ('screen_size_inch',   'Kích thước màn hình', 'number',  'inch', 'Màn hình',  TRUE,  1),
    ('screen_resolution',  'Độ phân giải',        'text',    NULL,   'Màn hình',  FALSE, 2),
    ('screen_refresh_rate','Tần số quét',          'number',  'Hz',   'Màn hình',  TRUE,  3),
    ('chipset',            'Chipset',              'text',    NULL,   'Hiệu năng', TRUE,  4),
    ('cpu',                'CPU',                  'text',    NULL,   'Hiệu năng', FALSE, 5),
    ('gpu',                'GPU',                  'text',    NULL,   'Hiệu năng', FALSE, 6),
    ('ram_gb',             'RAM',                  'number',  'GB',   'Hiệu năng', TRUE,  7),
    ('ram_type',           'Loại RAM',             'text',    NULL,   'Hiệu năng', FALSE, 8),
    ('storage_gb',         'Ổ cứng',               'number',  'GB',   'Hiệu năng', TRUE,  9),
    ('os',                 'Hệ điều hành',         'text',    NULL,   'Hiệu năng', TRUE,  10),
    ('battery_wh',         'Dung lượng pin',       'number',  'Wh',  'Pin & Sạc', FALSE, 11),
    ('battery_hours',      'Thời lượng pin',       'number',  'giờ', 'Pin & Sạc', TRUE,  12),
    ('weight_kg',          'Trọng lượng',          'number',  'kg',   'Thiết kế',  FALSE, 13),
    ('ports',              'Cổng kết nối',         'array',   NULL,   'Kết nối',   FALSE, 14)
) AS v(spec_key, display_name, data_type, unit, spec_group, is_filterable, sort_order)
WHERE c.slug = 'laptop';


-- ============================================================
-- SPEC TEMPLATES: tablet (tương tự smartphone)
-- ============================================================
INSERT INTO spec_templates (category_id, spec_key, display_name, data_type, unit, spec_group, is_filterable, sort_order)
SELECT c.category_id, v.spec_key, v.display_name, v.data_type, v.unit, v.spec_group, v.is_filterable, v.sort_order
FROM categories c,
(VALUES
    ('screen_size_inch',   'Kích thước màn hình', 'number',  'inch', 'Màn hình',  TRUE,  1),
    ('screen_resolution',  'Độ phân giải',        'text',    NULL,   'Màn hình',  FALSE, 2),
    ('screen_refresh_rate','Tần số quét',          'number',  'Hz',   'Màn hình',  TRUE,  3),
    ('chipset',            'Chipset',              'text',    NULL,   'Hiệu năng', TRUE,  4),
    ('ram_gb',             'RAM',                  'number',  'GB',   'Hiệu năng', TRUE,  5),
    ('storage_gb',         'Bộ nhớ trong',         'number',  'GB',   'Hiệu năng', TRUE,  6),
    ('os',                 'Hệ điều hành',         'text',    NULL,   'Hiệu năng', TRUE,  7),
    ('camera_main_mp',     'Camera chính',         'number',  'MP',   'Camera',    FALSE, 8),
    ('battery_mah',        'Dung lượng pin',       'number',  'mAh', 'Pin & Sạc', TRUE,  9),
    ('fast_charge_w',      'Sạc nhanh',            'number',  'W',    'Pin & Sạc', FALSE, 10),
    ('weight_g',           'Trọng lượng',          'number',  'g',    'Thiết kế',  FALSE, 11)
) AS v(spec_key, display_name, data_type, unit, spec_group, is_filterable, sort_order)
WHERE c.slug = 'tablet';


-- ============================================================
-- SPEC TEMPLATES: headphone
-- ============================================================
INSERT INTO spec_templates (category_id, spec_key, display_name, data_type, unit, spec_group, is_filterable, sort_order)
SELECT c.category_id, v.spec_key, v.display_name, v.data_type, v.unit, v.spec_group, v.is_filterable, v.sort_order
FROM categories c,
(VALUES
    ('headphone_type',       'Loại tai nghe',       'text',    NULL,   'Thông tin',  TRUE,  1),
    ('driver_size_mm',       'Kích thước driver',   'number',  'mm',   'Âm thanh',   FALSE, 2),
    ('driver_type',          'Loại driver',         'text',    NULL,   'Âm thanh',   FALSE, 3),
    ('battery_total_hours',  'Thời lượng pin tổng', 'number',  'giờ', 'Pin & Sạc',  TRUE,  4),
    ('wireless_charge',      'Sạc không dây',       'boolean', NULL,   'Pin & Sạc',  TRUE,  5),
    ('bluetooth_version',    'Phiên bản Bluetooth', 'text',    NULL,   'Kết nối',    FALSE, 6),
    ('anc',                  'Chống ồn ANC',        'boolean', NULL,   'Tính năng',  TRUE,  7),
    ('ip_rating',            'Chống nước',           'text',    NULL,   'Thiết kế',   TRUE,  8),
    ('weight_g',             'Trọng lượng',          'number',  'g',    'Thiết kế',   FALSE, 9)
) AS v(spec_key, display_name, data_type, unit, spec_group, is_filterable, sort_order)
WHERE c.slug = 'headphone';


-- ============================================================
-- SPEC TEMPLATES: smartwatch
-- ============================================================
INSERT INTO spec_templates (category_id, spec_key, display_name, data_type, unit, spec_group, is_filterable, sort_order)
SELECT c.category_id, v.spec_key, v.display_name, v.data_type, v.unit, v.spec_group, v.is_filterable, v.sort_order
FROM categories c,
(VALUES
    ('screen_size_mm',   'Kích thước mặt',      'number',  'mm',   'Màn hình',  TRUE,  1),
    ('screen_technology','Công nghệ màn hình',  'text',    NULL,   'Màn hình',  FALSE, 2),
    ('always_on',        'Always-On Display',   'boolean', NULL,   'Màn hình',  TRUE,  3),
    ('chipset',          'Chipset',              'text',    NULL,   'Hiệu năng', FALSE, 4),
    ('os',               'Hệ điều hành',         'text',    NULL,   'Hiệu năng', TRUE,  5),
    ('battery_hours',    'Thời lượng pin',       'number',  'giờ', 'Pin & Sạc', TRUE,  6),
    ('sensors',          'Cảm biến',             'array',   NULL,   'Sức khỏe',  FALSE, 7),
    ('cellular',         'Hỗ trợ eSIM',          'boolean', NULL,   'Kết nối',   TRUE,  8),
    ('ip_rating',        'Chống nước',            'text',    NULL,   'Thiết kế',  TRUE,  9),
    ('weight_g',         'Trọng lượng',           'number',  'g',    'Thiết kế',  FALSE, 10)
) AS v(spec_key, display_name, data_type, unit, spec_group, is_filterable, sort_order)
WHERE c.slug = 'smartwatch';


-- ============================================================
-- SPEC TEMPLATES: accessory
-- ============================================================
INSERT INTO spec_templates (category_id, spec_key, display_name, data_type, unit, spec_group, is_filterable, sort_order)
SELECT c.category_id, v.spec_key, v.display_name, v.data_type, v.unit, v.spec_group, v.is_filterable, v.sort_order
FROM categories c,
(VALUES
    ('accessory_type',     'Loại phụ kiện',       'text',    NULL,   'Thông tin',  TRUE,  1),
    ('compatible_model',   'Tương thích với',     'text',    NULL,   'Thông tin',  TRUE,  2),
    ('material',           'Chất liệu',           'text',    NULL,   'Thiết kế',  FALSE, 3),
    ('connectivity',       'Kết nối',              'array',   NULL,   'Kết nối',   FALSE, 4)
) AS v(spec_key, display_name, data_type, unit, spec_group, is_filterable, sort_order)
WHERE c.slug = 'accessory';
