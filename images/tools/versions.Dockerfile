{% if params['versions']['openssl'] %}ARG openssl_version={{params['versions']['openssl']}}{% endif %}
{% if params['versions']['cmake'] %}ARG cmake_version={{params['versions']['cmake']}}{% endif %}
{% if params['versions']['doxygen'] %}ARG doxygen_version={{params['versions']['doxygen']}}{% endif %}
{% if params['versions']['lcov'] %}ARG lcov_version={{params['versions']['lcov']}}{% endif %}
