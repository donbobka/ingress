require "ingress/permissions_repository"
require "ingress/copy_permissions_repository_into_role"
require "ingress/build_permissions_repository_for_role"

module Ingress
  class Permissions
    class << self
      def permissions_repository
        @permissions_repository ||= PermissionsRepository.new
      end

      def inherits(permissions_class)
        role_identifier = :dummy

        if permissions_class
          @permissions_repository = permissions_repository.merge(
            Services::CopyPermissionsRepositoryIntoRole.perform(role_identifier, permissions_class.permissions_repository),
          )
        end
      end

      def define_role_permissions(role_identifier = nil, permissions_class = nil, &block)
        if role_identifier.nil?
          role_identifier = :dummy
        end

        if permissions_class
          @permissions_repository = permissions_repository.merge(
            Services::CopyPermissionsRepositoryIntoRole.perform(role_identifier, permissions_class.permissions_repository),
          )
        end

        if block_given?
          @permissions_repository = permissions_repository.merge(Services::BuildPermissionsRepositoryForRole.perform(role_identifier, &block))
        end
      end
    end

    attr_reader :user

    def initialize(user)
      @user = user
    end

    def can?(action, subject)
      find_matching_rules(action, subject).any? do |rule|
        rule.match?(action, subject, user)
      end
    end

    def user_role_identifiers
      []
    end

    private

    def find_matching_rules(action, subject)
      user_role_identifiers.reduce([]) do |rules, role_identifier|
        rules += self.class.permissions_repository.rules_for(role_identifier, action, subject)
        rules
      end
    end
  end
end
