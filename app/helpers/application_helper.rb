module ApplicationHelper
  STORE_LOGOS = {
    "Jumia" => "https://upload.wikimedia.org/wikipedia/commons/a/a7/Jumia_Group-Logo.png",
    "Jiji" => "https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/Jiji_africa.jpg/250px-Jiji_africa.jpg",
    "CompuGhana" => "https://www.zaatu.com/wp-content/uploads/2022/10/ZAATU-Web-Art-2865-2900.jpg",
    "Telefonika" => "https://telefonika.com/cdn/shop/files/Screenshot_2025-07-15_095610.png?v=1760174070",
    "Amazon" => "https://upload.wikimedia.org/wikipedia/commons/thumb/0/06/Amazon_2024.svg/330px-Amazon_2024.svg.png"
  }.freeze

  def store_logo_url(store)
    STORE_LOGOS[store]
  end
end
