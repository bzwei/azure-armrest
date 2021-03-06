########################################################################
# test_virtual_machine_manager.rb
#
# Test suite for the Azure::Armrest::VirtualMachineManager class.
########################################################################

require 'spec_helper'

describe "VirtualMachineManager" do
  before { setup_params }
  let(:vmm) { Azure::Armrest::VirtualMachineManager.new(@params) }

  context "inheritance" do
    it "is a subclass of ArmrestManager" do
      Azure::Armrest::VirtualMachineManager.ancestors.should include(Azure::Armrest::ArmrestManager)
    end
  end

  context "constructor" do
    it "returns a vmm instance as expected" do
      vmm.should be_kind_of(Azure::Armrest::VirtualMachineManager)
    end
  end

  context "constants" do
    it "defines VALID_VM_SIZES" do
      Azure::Armrest::VirtualMachineManager::VALID_VM_SIZES.should_not be_nil
      Azure::Armrest::VirtualMachineManager::VALID_VM_SIZES.should be_a_kind_of(Array)
      Azure::Armrest::VirtualMachineManager::VALID_VM_SIZES.size.should eql(5)
    end
  end

  context "accessors" do
    it "defines a base_url accessor" do
      vmm.should respond_to(:base_url)
      vmm.should respond_to(:base_url=)
    end
  end

  context "instance methods" do
    it "defines a capture method" do
      vmm.should respond_to(:capture)
    end

    it "defines a create method" do
      vmm.should respond_to(:create)
    end

    it "defines a deallocate method" do
      vmm.should respond_to(:deallocate)
    end

    it "defines a delete method" do
      vmm.should respond_to(:delete)
    end

    it "defines a generalize method" do
      vmm.should respond_to(:generalize)
    end

    it "defines a get method" do
      vmm.should respond_to(:get)
    end

    it "defines an operations method" do
      vmm.should respond_to(:operations)
    end

    it "defines an restart method" do
      vmm.should respond_to(:restart)
    end

    it "defines a start method" do
      vmm.should respond_to(:start)
    end

    it "defines a stop method" do
      vmm.should respond_to(:stop)
    end
  end
end
